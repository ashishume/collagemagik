import Foundation

/// Everything you may want to change about ads, in one place.
enum AdConfig {
    /// The Meta Audience Network **interstitial placement ID** for this app.
    ///
    /// Create it in Meta Monetization Manager (business.facebook.com/monetization_manager): add the iOS app with bundle ID
    /// `com.axpo.collagemagik`, then add an *Interstitial* placement and paste its ID here (it looks like `1234567890_1234567890`).
    ///
    /// While this is empty the app shows **no ads, no consent screen and no tracking prompt**, and the Meta SDK is never started.
    /// Debug builds can override it with the `CM_AD_PLACEMENT` environment variable for testing.
    static let interstitialPlacementID = ""

    /// An interstitial is considered after every Nth finished export (so the 1st export, the user's first impression, is ad-free).
    static let showEveryNthExport = 2

    /// Never show two ads closer together than this.
    static let minimumSecondsBetweenAds: TimeInterval = 180

    /// The placement ID in effect (the debug override, if any, else the one above).
    static var activePlacementID: String {
        #if DEBUG
        if let override = ProcessInfo.processInfo.environment["CM_AD_PLACEMENT"], !override.isEmpty { return override }
        #endif
        return interstitialPlacementID
    }

    static var isConfigured: Bool { !activePlacementID.isEmpty }

    /// Countries where ads need an explicit "yes" first (EU/EEA, UK and Switzerland). Elsewhere Apple's tracking prompt is the choice.
    private static let explicitConsentRegions: Set<String> = [
        "AT", "BE", "BG", "HR", "CY", "CZ", "DK", "EE", "FI", "FR", "DE", "GR", "HU", "IE", "IT", "LV", "LT", "LU", "MT", "NL", "PL",
        "PT", "RO", "SK", "SI", "ES", "SE", "IS", "LI", "NO", "GB", "CH",
    ]

    static var requiresExplicitConsent: Bool {
        guard let region = Locale.current.region?.identifier else { return true } // unknown region: ask, to be safe
        return explicitConsentRegions.contains(region)
    }
}
