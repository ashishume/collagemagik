import Foundation
import Observation
import UIKit

/// Finds out whether a newer Collage Magic is on the App Store, without a server of our own: it asks Apple's public
/// lookup API (`itunes.apple.com/lookup`) for the live version and compares it with the one running.
///
/// It never interrupts: when there is an update, `TopBar` shows a small "Update" button that opens the App Store page.
/// Checked at launch and whenever the app comes back to the front, at most every few hours.
/// Only the app's own App Store ID and the device's store country are sent to Apple.
@MainActor
@Observable
final class UpdateChecker {
    static let shared = UpdateChecker()

    /// The App Store's version when it is newer than this one and this device can run it; nil otherwise.
    private(set) var availableVersion: String?
    var updateAvailable: Bool { availableVersion != nil }

    @ObservationIgnored private var lastCheck: Date?
    @ObservationIgnored private var checking = false
    @ObservationIgnored private let minInterval: TimeInterval = 4 * 60 * 60

    private static let appID = "6832640005"

    static var installedVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0"
    }

    private init() {
        #if DEBUG
        // CM_FAKE_UPDATE=1 shows the update button without a newer version on the store.
        if ProcessInfo.processInfo.environment["CM_FAKE_UPDATE"] == "1" { availableVersion = "99.0" }
        #endif
    }

    /// Safe to call often; looks again only when the last look is a few hours old.
    func checkIfDue() {
        if let lastCheck, Date().timeIntervalSince(lastCheck) < minInterval { return }
        Task { await check() }
    }

    func check() async {
        guard !checking else { return }
        #if DEBUG
        if ProcessInfo.processInfo.environment["CM_FAKE_UPDATE"] == "1" { return }
        #endif
        checking = true
        defer { checking = false }

        var parts = URLComponents(string: "https://itunes.apple.com/lookup")!
        parts.queryItems = [
            URLQueryItem(name: "id", value: Self.appID),
            // The lookup answers for one storefront (US by default); ask the one this person most likely uses.
            URLQueryItem(name: "country", value: Locale.current.region?.identifier.lowercased() ?? "us"),
        ]
        var request = URLRequest(url: parts.url!, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 15)
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        do {
            let (data, _) = try await URLSession.shared.data(for: request)
            let result = try JSONDecoder().decode(LookupResponse.self, from: data).results.first
            lastCheck = Date()
            guard let result else { return } // not in this storefront
            let newer = Self.isVersion(result.version, newerThan: Self.installedVersion)
            let runsHere = result.minimumOsVersion.map { !Self.isVersion($0, newerThan: UIDevice.current.systemVersion) } ?? true
            availableVersion = newer && runsHere ? result.version : nil
            NSLog("CM_UPDATE store %@, installed %@, update %@", result.version, Self.installedVersion, availableVersion ?? "none")
        } catch {
            NSLog("CM_UPDATE lookup failed: %@", error.localizedDescription)
        }
    }

    /// Compares dotted versions number by number: "1.10" is newer than "1.9", "1.0.1" newer than "1.0".
    static func isVersion(_ a: String, newerThan b: String) -> Bool {
        let x = a.split(separator: ".").map { Int($0) ?? 0 }
        let y = b.split(separator: ".").map { Int($0) ?? 0 }
        for i in 0..<max(x.count, y.count) {
            let l = i < x.count ? x[i] : 0, r = i < y.count ? y[i] : 0
            if l != r { return l > r }
        }
        return false
    }

    private struct LookupResponse: Decodable {
        let results: [Result]
        struct Result: Decodable {
            let version: String
            let minimumOsVersion: String?
        }
    }
}
