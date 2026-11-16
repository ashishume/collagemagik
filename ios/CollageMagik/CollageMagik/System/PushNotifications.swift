import FirebaseCore
import FirebaseMessaging
import SwiftUI
import UIKit
import UserNotifications

/// Push notifications through Firebase Cloud Messaging, so they can be sent from the Firebase console
/// (Messaging → New campaign) with no server of our own. Apple's APNs key is uploaded once in the Firebase console
/// (Project settings → Cloud Messaging); it is never part of the app.
///
/// * At launch the app asks for *provisional* permission: no dialog, notifications arrive quietly in Notification Centre
///   with "Keep / Turn off" buttons.
/// * After a finished export (a happy moment, and never on top of the ads notice) it asks once for full permission, so
///   notifications can show as banners.
/// * A notification may carry a `link` (custom data in the console) that opens when it is tapped, e.g. the App Store page.
@MainActor
final class PushNotifications: NSObject {
    static let shared = PushNotifications()

    private let defaults = UserDefaults.standard
    private let askedKey = "cm.push.askedFull"
    private var started = false

    /// Called from the app delegate at launch, before any UI.
    func start(application: UIApplication) {
        guard !started, FirebaseBoot.configure() else { return }
        started = true
        UNUserNotificationCenter.current().delegate = self
        Messaging.messaging().delegate = self
        Task {
            let settings = await UNUserNotificationCenter.current().notificationSettings()
            if settings.authorizationStatus == .notDetermined {
                _ = try? await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound, .provisional])
            }
            application.registerForRemoteNotifications()
        }
    }

    /// After a finished export: the one time the app shows the full "Allow notifications?" question.
    func exportFinished() {
        guard started, !defaults.bool(forKey: askedKey) else { return }
        Task {
            // let the export sheet (and the ads notice, if it is about to show) settle first
            try? await Task.sleep(for: .seconds(1.4))
            guard !AdManager.shared.showNotice else { return } // try again after the next export
            let status = await UNUserNotificationCenter.current().notificationSettings().authorizationStatus
            guard status == .notDetermined || status == .provisional else {
                defaults.set(true, forKey: askedKey)
                return
            }
            defaults.set(true, forKey: askedKey)
            let granted = (try? await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound])) ?? false
            NSLog("CM_PUSH full permission %@", granted ? "granted" : "declined")
            if granted { UIApplication.shared.registerForRemoteNotifications() }
        }
    }

    func didRegister(deviceToken: Data) {
        Messaging.messaging().apnsToken = deviceToken
    }

    /// Tapping a notification with a `link` opens it (an https link, e.g. the App Store page or a web page).
    fileprivate func open(_ userInfo: [AnyHashable: Any]) {
        guard let s = userInfo["link"] as? String, let url = URL(string: s), url.scheme == "https" else { return }
        UIApplication.shared.open(url)
    }
}

extension PushNotifications: @preconcurrency UNUserNotificationCenterDelegate {
    /// Show banners even while the app is open.
    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification) async -> UNNotificationPresentationOptions {
        [.banner, .list, .sound]
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse) async {
        open(response.notification.request.content.userInfo)
    }
}

extension PushNotifications: @preconcurrency MessagingDelegate {
    func messaging(_ messaging: Messaging, didReceiveRegistrationToken fcmToken: String?) {
        #if DEBUG
        // Paste this into Firebase console → Messaging → "Send test message" to try a push on this device.
        NSLog("CM_PUSH FCM token: %@", fcmToken ?? "nil")
        #endif
        // Everyone gets the "all" topic, so a campaign can also be sent to the topic.
        if fcmToken != nil { messaging.subscribe(toTopic: "all") }
    }
}

/// Starts Firebase once, for whichever part needs it first (push at launch, analytics after the consent step).
///
/// Analytics collection is off in `AdInfo.plist` (`FIREBASE_ANALYTICS_COLLECTION_ENABLED`), so starting Firebase early for
/// push sends no analytics; `InstallTracking` switches collection on only after the consent step, as before.
@MainActor
enum FirebaseBoot {
    private static var done = false

    /// True when Firebase is running (false when `GoogleService-Info.plist` is missing).
    @discardableResult
    static func configure() -> Bool {
        if done { return true }
        guard Bundle.main.path(forResource: "GoogleService-Info", ofType: "plist") != nil else { return false }
        FirebaseApp.configure()
        done = true
        return true
    }
}

/// UIKit's hooks that SwiftUI has no equivalent for: the APNs device token.
final class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        MainActor.assumeIsolated { PushNotifications.shared.start(application: application) }
        return true
    }

    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        MainActor.assumeIsolated { PushNotifications.shared.didRegister(deviceToken: deviceToken) }
    }

    func application(_ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {
        NSLog("CM_PUSH APNs registration failed: %@", error.localizedDescription)
    }
}
