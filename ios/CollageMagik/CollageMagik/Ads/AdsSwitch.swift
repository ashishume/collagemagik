import Foundation

/// Which ad network the app uses. There is no backend, so this file is the switch: change a value and ship a new build.
///
/// * `googleAdsEnabled = true`: Google AdMob. A small banner above the bottom tool bar on every tab, and one full-screen ad after
///   an export finishes, before the result is shown.
/// * `metaAdsEnabled = true`: Meta Audience Network (the older setup in `AdManager`; it also needs a placement ID in `AdConfig`).
///
/// Turn on only one. If both are on, Google wins and Meta stays off.
enum AdsSwitch {
    static let googleAdsEnabled = true
    static let metaAdsEnabled = false

    static var useGoogle: Bool { googleAdsEnabled }
    static var useMeta: Bool { metaAdsEnabled && !googleAdsEnabled }
}

/// Google AdMob IDs. The app ID itself lives in `AdInfo.plist` (`GADApplicationIdentifier`), where the SDK reads it.
enum GoogleAdConfig {
    static let appID = "ca-app-pub-3743383597691737~8957379689"
    private static let liveBannerUnitID = "ca-app-pub-3743383597691737/1946228718"
    private static let liveInterstitialUnitID = "ca-app-pub-3743383597691737/3067738697"

    // Google's public test units. Debug builds use them, so testing never clicks real ads (which can get an AdMob account suspended).
    private static let testBannerUnitID = "ca-app-pub-3940256099942544/2435281174"
    private static let testInterstitialUnitID = "ca-app-pub-3940256099942544/4411468910"

    static var bannerUnitID: String {
        #if DEBUG
        if ProcessInfo.processInfo.environment["CM_LIVE_ADS"] == "1" { return liveBannerUnitID }
        return testBannerUnitID
        #else
        return liveBannerUnitID
        #endif
    }

    static var interstitialUnitID: String {
        #if DEBUG
        if ProcessInfo.processInfo.environment["CM_LIVE_ADS"] == "1" { return liveInterstitialUnitID }
        return testInterstitialUnitID
        #else
        return liveInterstitialUnitID
        #endif
    }

    /// Show the full-screen ad after every Nth finished export (1 = every export).
    static let interstitialEveryNthExport = 1
    /// Never show two full-screen ads closer together than this.
    static let minimumSecondsBetweenInterstitials: TimeInterval = 0
    /// If the full-screen ad is still loading when an export finishes, wait at most this long before showing the result anyway.
    static let maxWaitForInterstitial: TimeInterval = 3
}
