import AppTrackingTransparency
import FBAudienceNetwork
import SwiftUI

/// Meta Audience Network ads, kept deliberately small and polite:
///
/// * One full-screen ad, only **after** an export finishes and its sheet is closed, never while editing.
/// * Not on the first export, at most every `AdConfig.showEveryNthExport` exports, and never within `minimumSecondsBetweenAds`.
/// * The Meta SDK is not started until the person has seen the ads notice (and, in the EU/UK, agreed). Nothing is collected before that.
/// * Photos, videos, music and collages are never given to the ad SDK.
@MainActor
@Observable
final class AdManager {
    static let shared = AdManager()

    enum Choice: String { case allowed, declined }

    /// Drives the ads notice sheet in `RootView`.
    var showNotice = false
    private(set) var choice: Choice?
    private(set) var sdkStarted = false

    private var interstitial: FBInterstitialAd?
    private var delegate: InterstitialDelegate?
    private var adIsReady = false
    private var isLoading = false

    private let defaults = UserDefaults.standard
    private enum Key {
        static let choice = "ads.choice"
        static let exports = "ads.finishedExports"
        static let lastShown = "ads.lastShown"
    }

    private init() {
        choice = defaults.string(forKey: Key.choice).flatMap(Choice.init(rawValue:))
    }

    /// False until Meta is switched on in `AdsSwitch` and a placement ID is set in `AdConfig`.
    var isEnabled: Bool { AdsSwitch.useMeta && AdConfig.isConfigured && !ProStore.shared.isPro }

    var trackingStatus: ATTrackingManager.AuthorizationStatus { ATTrackingManager.trackingAuthorizationStatus }

    // MARK: Lifecycle

    /// Call once at launch. Starts the SDK only if the person already agreed in an earlier session.
    func appDidLaunch() {
        guard isEnabled, choice == .allowed else { return }
        startSDK()
    }

    /// Call when the export sheet closes. `finished` is true when an export had completed in it.
    func exportSheetClosed(finished: Bool) {
        guard isEnabled else { return }
        if finished { defaults.set(defaults.integer(forKey: Key.exports) + 1, forKey: Key.exports) }
        guard finished else { return }

        switch choice {
        case .none:
            // First finished export: explain the ads, once, after the sheet has gone.
            Task { try? await Task.sleep(for: .seconds(0.7)); showNotice = true }
        case .declined:
            break
        case .allowed:
            guard isDue else { return }
            Task { try? await Task.sleep(for: .seconds(0.7)); presentInterstitial() }
        }
    }

    /// The person answered the ads notice.
    func noticeAnswered(_ answer: Choice) {
        choice = answer
        defaults.set(answer.rawValue, forKey: Key.choice)
        showNotice = false
        guard answer == .allowed, isEnabled else { return }
        Task {
            try? await Task.sleep(for: .seconds(0.6)) // let the sheet finish closing: the system prompt needs an active app
            _ = await ATTrackingManager.requestTrackingAuthorization()
            startSDK() // the SDK reads the tracking status itself (iOS 17+)
        }
    }

    /// "Delete all my data" also clears ad choices, so the notice is shown again next time.
    func resetChoices() {
        choice = nil
        [Key.choice, Key.exports, Key.lastShown].forEach { defaults.removeObject(forKey: $0) }
        interstitial = nil
        adIsReady = false
    }

    /// The notice was closed without an answer (swiped away): it comes back after the next finished export.
    func noticeDismissed() { showNotice = false }

    // MARK: Frequency

    private var isDue: Bool {
        let exports = defaults.integer(forKey: Key.exports)
        guard exports > 0, exports % AdConfig.showEveryNthExport == 0 else { return false }
        let last = defaults.object(forKey: Key.lastShown) as? Date ?? .distantPast
        return Date().timeIntervalSince(last) >= AdConfig.minimumSecondsBetweenAds
    }

    // MARK: Meta SDK

    private func startSDK() {
        guard !sdkStarted, isEnabled else { return }
        sdkStarted = true
        #if DEBUG
        FBAdSettings.addTestDevice(FBAdSettings.testDeviceHash())
        #endif
        FBAdSettings.isMixedAudience = false // CollageMagik is not directed at children
        FBAudienceNetworkAds.initialize(with: nil) { [weak self] results in
            Task { @MainActor in
                NSLog("CM_ADS sdk initialised: %@ (%@)", results.isSuccess ? "ok" : "failed", results.message)
                if results.isSuccess { self?.loadInterstitial() }
            }
        }
    }

    private func loadInterstitial() {
        guard sdkStarted, !isLoading, !adIsReady else { return }
        isLoading = true
        let ad = FBInterstitialAd(placementID: AdConfig.activePlacementID)
        let delegate = InterstitialDelegate(
            onLoad: { [weak self] in Task { @MainActor in self?.isLoading = false; self?.adIsReady = true } },
            onFail: { [weak self] error in
                Task { @MainActor in
                    NSLog("CM_ADS load failed: %@", error.localizedDescription)
                    self?.isLoading = false
                    self?.adIsReady = false
                    self?.interstitial = nil
                    // No fill is normal. Try again later, not immediately.
                    try? await Task.sleep(for: .seconds(90))
                    self?.loadInterstitial()
                }
            },
            onClose: { [weak self] in
                Task { @MainActor in
                    self?.interstitial = nil
                    self?.adIsReady = false
                    self?.loadInterstitial() // have the next one ready
                }
            }
        )
        ad.delegate = delegate
        self.delegate = delegate
        interstitial = ad
        // Meta's current docs load a client-side interstitial with `load()`. Its header marks it deprecated in favour of a
        // server-side bid payload (`loadAd(withBidPayload:)`); revisit if a later SDK removes it.
        ad.load()
    }

    private func presentInterstitial() {
        guard choice == .allowed, sdkStarted, adIsReady, let ad = interstitial, ad.isAdValid, let top = Self.topViewController() else { return }
        defaults.set(Date(), forKey: Key.lastShown)
        adIsReady = false
        _ = ad.show(fromRootViewController: top)
    }

    private static func topViewController() -> UIViewController? {
        let scene = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first { $0.activationState == .foregroundActive }
        var top = scene?.keyWindow?.rootViewController
        while let presented = top?.presentedViewController { top = presented }
        return top
    }
}

/// Bridges Meta's Objective-C delegate to closures.
private final class InterstitialDelegate: NSObject, FBInterstitialAdDelegate {
    let onLoad: () -> Void
    let onFail: (Error) -> Void
    let onClose: () -> Void

    init(onLoad: @escaping () -> Void, onFail: @escaping (Error) -> Void, onClose: @escaping () -> Void) {
        self.onLoad = onLoad
        self.onFail = onFail
        self.onClose = onClose
    }

    func interstitialAdDidLoad(_ interstitialAd: FBInterstitialAd) { onLoad() }
    func interstitialAd(_ interstitialAd: FBInterstitialAd, didFailWithError error: Error) { onFail(error) }
    func interstitialAdDidClose(_ interstitialAd: FBInterstitialAd) { onClose() }
}
