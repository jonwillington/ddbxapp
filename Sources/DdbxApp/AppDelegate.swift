import UIKit

class AppDelegate: NSObject, UIApplicationDelegate {
    var pushManager: PushManager?

    func application(
        _ application: UIApplication,
        didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
    ) {
        Task { @MainActor in
            pushManager?.didRegisterForRemoteNotifications(token: deviceToken)
        }
    }

    func application(
        _ application: UIApplication,
        didFailToRegisterForRemoteNotificationsWithError error: Error
    ) {
        Task { @MainActor in
            pushManager?.didFailToRegisterForRemoteNotifications(error: error)
        }
    }
}
