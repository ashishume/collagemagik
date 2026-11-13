import AppTrackingTransparency
import GoogleMobileAds
import SwiftUI
import UserMessagingPlatform

/// Google AdMob, switched on in `AdsSwitch`:
///
/// * A small banner above the bottom tool bar (`AdBannerSlot`), the same one on every tab, never over the collage or its tools.
/// * One full-screen ad after an export finishes, **before** the result is shown, so it never interrupts editing.
/// * At first launch: Google's consent message (UMP; in the EU/UK no ad is requested until the person has answered it), then
///   Apple's tracking question, then the SDK starts.
/// * Before the first full-screen ad, a short thank-you note explains that ads keep the app alive.
/// * Photos, videos, music and collages are never given to the ad SDK.
@MainActor
@Observable
final class GoogleAdsManager: NSObject {
    static let shared = GoogleAdsManager()

    /// True once consent allows ads and the SDK has started. Drives the banner.
    private(set) var canShowAds = false
    /// The EU/UK consent form must stay reachable: shown as "Ad privacy choices" in About when true.
    private(set) var privacyOptionsRequired = false

    private var started = false
    private var interstitial: InterstitialAd?
    private var loadingInterstitial = false
    private var dismissed: CheckedContinuation<Void, Never>?

    private let defaults = UserDefaults.standard
    private enum Key {
        static let exports = "gads.finishedExports"
        static let lastShown = "gads.lastInterstitial"
        static let thanked = "gads.thanksShown"
    }

    /// Google ads are switched on and the person doesn't have Pro.
    var isEnabled: Bool { AdsSwitch.useGoogle && !ProStore.shared.isPro }

    // MARK: Start-up and consent

    /// Call once at launch, in Google's recommended order: Google's consent message if needed (EU/UK), then Apple's tracking
    /// question (first launch only), then the SDK. Asking at launch means everyone sees the tracking question, App Review included.
    func appDidLaunch() {
        guard isEnabled, !started else { return }
        let params = RequestParameters()
        #if DEBUG
        if ProcessInfo.processInfo.environment["CM_CONSENT_EEA"] == "1" {
            let debug = DebugSettings()
            debug.geography = .EEA
            params.debugSettings = debug
        }
        #endif
        // A choice made on an earlier launch: ads can start straight away, while the consent info refreshes.
        startIfAllowed()
        ConsentInformation.shared.requestConsentInfoUpdate(with: params) { [weak self] error in
            Task { @MainActor in
                guard let self else { return }
                if let error { NSLog("CM_GADS consent info failed: %@", error.localizedDescription) }
                await self.presentConsentFormIfRequired()
                self.refreshPrivacyStatus()
                await self.requestTrackingIfNeeded()
                self.startIfAllowed()
            }
        }
    }

    private func presentConsentFormIfRequired() async {
        guard let top = Self.topViewController() else { return }
        await withCheckedContinuation { (c: CheckedContinuation<Void, Never>) in
            ConsentForm.loadAndPresentIfRequired(from: top) { error in
                if let error { NSLog("CM_GADS consent form: %@", error.localizedDescription) }
                c.resume()
            }
        }
    }

    private func refreshPrivacyStatus() {
        privacyOptionsRequired = ConsentInformation.shared.privacyOptionsRequirementStatus == .required
    }

    /// "Ad privacy choices" in About (EU/UK): reopens Google's consent form.
    func presentPrivacyOptions() {
        guard let top = Self.topViewController() else { return }
        ConsentForm.presentPrivacyOptionsForm(from: top) { [weak self] error in
            Task { @MainActor in
                if let error { NSLog("CM_GADS privacy options: %@", error.localizedDescription) }
                self?.refreshPrivacyStatus()
                self?.startIfAllowed()
            }
        }
    }

    private func startIfAllowed() {
        guard isEnabled, !started, ConsentInformation.shared.canRequestAds else { return }
        started = true
        InstallTracking.startIfAllowed() // counts the install for Google Ads campaigns (no-op until Firebase is set up)
        MobileAds.shared.start { [weak self] _ in
            Task { @MainActor in
                NSLog("CM_GADS sdk started")
                self?.canShowAds = true
                self?.loadInterstitial()
            }
        }
    }

    // MARK: Full-screen ad after export

    /// Call when an export has finished, before its result is shown. Returns once the ad (if any) has been closed.
    func beforeShowingExportResult() async {
        guard isEnabled, canShowAds else { return }
        let count = defaults.integer(forKey: Key.exports) + 1
        defaults.set(count, forKey: Key.exports)
        guard count % max(1, GoogleAdConfig.interstitialEveryNthExport) == 0 else { return }
        let last = defaults.object(forKey: Key.lastShown) as? Date ?? .distantPast
        guard Date().timeIntervalSince(last) >= GoogleAdConfig.minimumSecondsBetweenInterstitials else { return }

        if !defaults.bool(forKey: Key.thanked) {
            let wantsPro = await showThanks()
            defaults.set(true, forKey: Key.thanked)
            if wantsPro {
                // no ad this time: show what Pro is instead
                ProStore.shared.openPaywall()
                return
            }
        }

        if interstitial == nil {
            loadInterstitial()
            let deadline = Date().addingTimeInterval(GoogleAdConfig.maxWaitForInterstitial)
            while interstitial == nil, loadingInterstitial, Date() < deadline {
                try? await Task.sleep(for: .milliseconds(100))
            }
        }
        guard let ad = interstitial, let top = Self.topViewController() else { return }
        interstitial = nil
        ad.fullScreenContentDelegate = self
        defaults.set(Date(), forKey: Key.lastShown)
        await withCheckedContinuation { (c: CheckedContinuation<Void, Never>) in
            dismissed = c
            ad.present(from: top)
        }
        loadInterstitial() // have the next one ready
    }

    private func loadInterstitial() {
        guard canShowAds, interstitial == nil, !loadingInterstitial else { return }
        loadingInterstitial = true
        InterstitialAd.load(with: GoogleAdConfig.interstitialUnitID, request: Request()) { [weak self] ad, error in
            Task { @MainActor in
                guard let self else { return }
                self.loadingInterstitial = false
                if let error {
                    NSLog("CM_GADS interstitial failed: %@", error.localizedDescription)
                    // No fill is normal: try again later, not in a loop.
                    try? await Task.sleep(for: .seconds(60))
                    self.loadInterstitial()
                    return
                }
                self.interstitial = ad
                NSLog("CM_GADS interstitial ready")
            }
        }
    }

    private func finishPresentation() {
        dismissed?.resume()
        dismissed = nil
    }

    // MARK: The thank-you note

    /// Shown once, before the first full-screen ad. Returns true if the person chose "Remove ads with Pro".
    private func showThanks() async -> Bool {
        guard let top = Self.topViewController() else { return false }
        return await withCheckedContinuation { (c: CheckedContinuation<Bool, Never>) in
            let alert = UIAlertController(
                title: "Thank you for using Insta Collage 💜",
                message: "Insta Collage is made by a tiny team and is free for everyone, with no account. A short ad after you export is what keeps the app alive and lets us keep improving it.\n\nYour photos and videos never leave your iPhone. Thank you for your support!",
                preferredStyle: .alert
            )
            let ok = UIAlertAction(title: "Happy to help", style: .default) { _ in c.resume(returning: false) }
            alert.addAction(ok)
            alert.addAction(UIAlertAction(title: "Remove ads with Pro", style: .default) { _ in c.resume(returning: true) })
            alert.preferredAction = ok
            top.present(alert, animated: true)
        }
    }

    /// Apple's tracking question, once. Ads still show if the person says no, just without the advertising ID.
    private func requestTrackingIfNeeded() async {
        guard ATTrackingManager.trackingAuthorizationStatus == .notDetermined else { return }
        // Apple's prompt only appears in an active app: wait for launch (or the consent form) to settle first.
        try? await Task.sleep(for: .seconds(0.5))
        for _ in 0..<50 where UIApplication.shared.applicationState != .active {
            try? await Task.sleep(for: .milliseconds(200))
        }
        _ = await ATTrackingManager.requestTrackingAuthorization()
    }

    static func topViewController() -> UIViewController? {
        let scene = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
            .first { $0.activationState == .foregroundActive } ?? UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first
        var top = scene?.keyWindow?.rootViewController
        while let presented = top?.presentedViewController, !presented.isBeingDismissed { top = presented }
        return top
    }
}

extension GoogleAdsManager: FullScreenContentDelegate {
    nonisolated func adDidDismissFullScreenContent(_ ad: FullScreenPresentingAd) {
        Task { @MainActor in self.finishPresentation() }
    }

    nonisolated func ad(_ ad: FullScreenPresentingAd, didFailToPresentFullScreenContentWithError error: Error) {
        NSLog("CM_GADS present failed: %@", error.localizedDescription)
        Task { @MainActor in self.finishPresentation() }
    }
}

// MARK: - Banner

/// The banner slot: takes no room until ads are allowed, and folds away again if no ad comes.
struct AdBannerSlot: View {
    @State private var failed = false
    private let ads = GoogleAdsManager.shared

    var body: some View {
        if ads.isEnabled, ads.canShowAds, !failed {
            BannerRepresentable(failed: $failed)
                .frame(width: AdSizeBanner.size.width, height: AdSizeBanner.size.height)
                .frame(maxWidth: .infinity)
                .accessibilityLabel("Advertisement")
                .transition(.opacity)
        }
        Color.clear.frame(height: 0)
            .task(id: failed) {
                // no ad came: try again in a minute, without leaving an empty gap meanwhile
                guard failed else { return }
                try? await Task.sleep(for: .seconds(60))
                failed = false
            }
    }
}

private struct BannerRepresentable: UIViewRepresentable {
    @Binding var failed: Bool

    func makeCoordinator() -> Coordinator { Coordinator(failed: $failed) }

    func makeUIView(context: Context) -> BannerView {
        let banner = BannerView(adSize: AdSizeBanner)
        // the banner must have its size before it asks for an ad, or AdMob refuses with "Invalid ad width or height"
        banner.frame = CGRect(origin: .zero, size: AdSizeBanner.size)
        banner.adUnitID = GoogleAdConfig.bannerUnitID
        banner.rootViewController = GoogleAdsManager.topViewController()
        banner.delegate = context.coordinator
        banner.load(Request())
        return banner
    }

    func updateUIView(_ banner: BannerView, context: Context) {
        if banner.rootViewController == nil { banner.rootViewController = GoogleAdsManager.topViewController() }
    }

    final class Coordinator: NSObject, BannerViewDelegate {
        let failed: Binding<Bool>
        init(failed: Binding<Bool>) { self.failed = failed }

        func bannerViewDidReceiveAd(_ bannerView: BannerView) {
            NSLog("CM_GADS banner loaded")
        }

        func bannerView(_ bannerView: BannerView, didFailToReceiveAdWithError error: Error) {
            NSLog("CM_GADS banner failed: %@", error.localizedDescription)
            withAnimation(.smooth) { failed.wrappedValue = true }
        }
    }
}
