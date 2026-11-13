import FirebaseAnalytics
import FirebaseCore
import Foundation

/// Tells Google Ads that someone installed and opened the app, so a campaign can count installs.
///
/// Google Ads reads installs from Google Analytics for Firebase: once the SDK is running, its automatic `first_open` event is the
/// install, and Google Ads can import it as a conversion (see "Install tracking" in `ios/README.md`). Apple's SKAdNetwork IDs in
/// `AdInfo.plist` let Google count installs even when the person says no to tracking.
///
/// * Off until `GoogleService-Info.plist` (from the Firebase console) is added to the `CollageMagik/` folder. Without the file
///   nothing starts and nothing is sent, so the app is safe to ship before Firebase is set up.
/// * Starts only after the same consent step as the ads (`GoogleAdsManager.startIfAllowed`): in the EU/UK after the person has
///   answered Google's consent form, elsewhere right after Apple's tracking question.
/// * Photos, videos, music and collages are never given to the SDK, and the app logs no custom events of its own.
/// * Debug builds stay silent (so simulator runs don't count as installs). `CM_ANALYTICS=1` turns it on for testing.
@MainActor
enum InstallTracking {
    private static var started = false

    /// True when the Firebase config file is in the app.
    static var isConfigured: Bool { Bundle.main.path(forResource: "GoogleService-Info", ofType: "plist") != nil }

    /// Safe to call as often as you like; starts the SDK once.
    static func startIfAllowed() {
        guard !started, isConfigured else { return }
        #if DEBUG
        guard ProcessInfo.processInfo.environment["CM_ANALYTICS"] == "1" else { return }
        #endif
        started = true
        FirebaseApp.configure()
        NSLog("CM_INSTALL tracking started")
    }
}
