import BackgroundTasks
import UserNotifications
import Foundation

/// Wraps BGAppRefreshTask so it can be passed across concurrency boundaries.
final class SendableTaskBox: Sendable {
    nonisolated(unsafe) let task: BGAppRefreshTask
    init(_ task: BGAppRefreshTask) { self.task = task }
}

enum BackgroundRefresh {
    static let taskIdentifier = "uk.ddbx.app.refresh"

    /// Register the handler — call once at app launch.
    static func register() {
        BGTaskScheduler.shared.register(
            forTaskWithIdentifier: taskIdentifier,
            using: nil
        ) { bgTask in
            guard let refreshTask = bgTask as? BGAppRefreshTask else { return }
            handleRefresh(refreshTask)
        }
    }

    /// Schedule the next background fetch.
    static func scheduleNext() {
        let request = BGAppRefreshTaskRequest(identifier: taskIdentifier)
        request.earliestBeginDate = Date(timeIntervalSinceNow: 30 * 60)
        do {
            try BGTaskScheduler.shared.submit(request)
        } catch {
            print("[bg] schedule error: \(error)")
        }
    }

    // MARK: - Private

    private static func handleRefresh(_ bgTask: BGAppRefreshTask) {
        scheduleNext()

        let box = SendableTaskBox(bgTask)

        let operation = Task.detached {
            do {
                let oldFingerprint = UserDefaults.standard.string(forKey: "versionFingerprint")
                let version = try await APIClient.shared.version()
                let newFingerprint = "\(version.latest ?? ""):\(version.total)"

                UserDefaults.standard.set(newFingerprint, forKey: "versionFingerprint")

                if let old = oldFingerprint, old != newFingerprint {
                    await postLocalNotification()
                }

                box.task.setTaskCompleted(success: true)
            } catch {
                box.task.setTaskCompleted(success: false)
            }
        }

        bgTask.expirationHandler = {
            operation.cancel()
        }
    }

    private static func postLocalNotification() async {
        let content = UNMutableNotificationContent()
        content.title = "New dealings available"
        content.body = "New director dealings have been disclosed. Open ddbx to see them."
        content.sound = .default
        content.threadIdentifier = "bg-refresh"

        let request = UNNotificationRequest(
            identifier: "bg-new-deals-\(Date.now.timeIntervalSince1970)",
            content: content,
            trigger: nil
        )

        try? await UNUserNotificationCenter.current().add(request)
    }
}
