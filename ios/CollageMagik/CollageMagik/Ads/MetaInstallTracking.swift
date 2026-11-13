import FacebookCore
import UIKit

/// Tells Meta that someone installed and opened the app, so Meta app install campaigns can count installs and optimise for
/// them (Meta's iOS 14+ campaigns refuse apps that send no install data).
///
/// * Meta app "Axpo Collage Maker" (ID and client token in `AdInfo.plist`). Automatic event logging and advertiser-ID collection
///   are off at launch and switched on here, so nothing is sent before the person has gone through the ad consent step.
/// * Starts at the same point as the Google ads and Firebase (`GoogleAdsManager.startIfAllowed`): in the EU/UK after Google's
///   consent form, elsewhere after Apple's tracking question. The SDK reads Apple's tracking answer itself.
/// * Sends "app activated" each time the app comes to the foreground; Meta derives installs from the first one. The app logs no
///   custom events. Photos, videos, music and collages are never given to the SDK.
/// * Debug builds stay silent (so simulator runs don't count as installs). `CM_ANALYTICS=1` turns it on for testing.
@MainActor
enum MetaInstallTracking {
    private static var started = false
    private static var observer: NSObjectProtocol?

    static func startIfAllowed() {
        guard !started else { return }
        #if DEBUG
        guard ProcessInfo.processInfo.environment["CM_ANALYTICS"] == "1" else { return }
        #endif
        started = true
        Settings.shared.isAutoLogAppEventsEnabled = true
        Settings.shared.isAdvertiserIDCollectionEnabled = true
        ApplicationDelegate.shared.application(UIApplication.shared, didFinishLaunchingWithOptions: nil)
        AppEvents.shared.activateApp()
        observer = NotificationCenter.default.addObserver(
            forName: UIApplication.didBecomeActiveNotification, object: nil, queue: .main
        ) { _ in
            Task { @MainActor in AppEvents.shared.activateApp() }
        }
        NSLog("CM_INSTALL meta tracking started")
    }
}
