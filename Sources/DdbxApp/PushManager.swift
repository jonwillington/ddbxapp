import Foundation
import UserNotifications
import UIKit

// MARK: - Notification record

struct PushNotificationRecord: Codable, Identifiable, Sendable {
    let id: String
    let title: String
    let body: String
    let dealingId: String?
    let receivedAt: Date
}

// MARK: - Push manager

enum NotifyLevel: String, Codable, Sendable, CaseIterable {
    case off = "none"
    case noteworthy
    case all

    var title: String {
        switch self {
        case .off: return "None"
        case .noteworthy: return "Standouts only"
        case .all: return "Every buy"
        }
    }

    var subtitle: String {
        switch self {
        case .off: return "No pushes."
        case .noteworthy: return "Significant & noteworthy trades."
        case .all: return "Every disclosed buy."
        }
    }
}

@MainActor
final class PushManager: NSObject, ObservableObject {
    @Published private(set) var isRegistered = false
    @Published private(set) var permissionGranted = false
    @Published private(set) var deviceToken: String?

    /// Set by notification tap — the dashboard observes this to open a detail sheet
    @Published var pendingDealingId: String?

    /// Most-recent-first history of received push notifications (max 50)
    @Published private(set) var notificationHistory: [PushNotificationRecord] = []

    private static let notifyLevelKey = "ddbx.notifyLevel"
    private static let digestEnabledKey = "ddbx.digestEnabled"

    /// Per-device notification level. `.noteworthy` = significant+noteworthy only (default),
    /// `.all` = every disclosed buy, `.off` = no deal pushes. Persisted and re-sent on change.
    @Published var notifyLevel: NotifyLevel {
        didSet {
            guard oldValue != notifyLevel else { return }
            UserDefaults.standard.set(notifyLevel.rawValue, forKey: Self.notifyLevelKey)
            if let token = deviceToken {
                Task { await registerWithServer(token: token) }
            }
        }
    }

    /// Morning/close daily summary pushes. Default on.
    @Published var digestEnabled: Bool {
        didSet {
            guard oldValue != digestEnabled else { return }
            UserDefaults.standard.set(digestEnabled, forKey: Self.digestEnabledKey)
            if let token = deviceToken {
                Task { await registerWithServer(token: token) }
            }
        }
    }

    override init() {
        if let raw = UserDefaults.standard.string(forKey: Self.notifyLevelKey),
           let level = NotifyLevel(rawValue: raw) {
            notifyLevel = level
        } else {
            notifyLevel = .noteworthy
        }
        // UserDefaults.bool returns false for unset keys — explicit default on first launch.
        digestEnabled = UserDefaults.standard.object(forKey: Self.digestEnabledKey) as? Bool ?? true
        super.init()
        if let data = UserDefaults.standard.data(forKey: "ddbx.notificationHistory"),
           let records = try? JSONDecoder().decode([PushNotificationRecord].self, from: data) {
            notificationHistory = records
        }
    }

    private func recordRaw(id: String, title: String, body: String, dealingId: String?) {
        let rec = PushNotificationRecord(
            id: id,
            title: title,
            body: body,
            dealingId: dealingId,
            receivedAt: Date()
        )
        notificationHistory.insert(rec, at: 0)
        if notificationHistory.count > 50 {
            notificationHistory = Array(notificationHistory.prefix(50))
        }
        if let data = try? JSONEncoder().encode(notificationHistory) {
            UserDefaults.standard.set(data, forKey: "ddbx.notificationHistory")
        }
    }

    func requestPermission() async {
        let center = UNUserNotificationCenter.current()
        center.delegate = self
        do {
            let granted = try await center.requestAuthorization(options: [.alert, .badge, .sound])
            permissionGranted = granted
            if granted {
                UIApplication.shared.registerForRemoteNotifications()
            }
        } catch {
            print("[push] permission error: \(error)")
        }
    }

    func didRegisterForRemoteNotifications(token: Data) {
        let hex = token.map { String(format: "%02x", $0) }.joined()
        deviceToken = hex
        isRegistered = true
        Task { await registerWithServer(token: hex) }
    }

    func didFailToRegisterForRemoteNotifications(error: Error) {
        print("[push] registration failed: \(error)")
        isRegistered = false
    }

    // MARK: - Server registration

    private func registerWithServer(token: String) async {
        let url = URL(string: "https://api.ddbx.uk/api/devices")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        #if DEBUG
        let environment = "sandbox"
        #else
        let environment = "production"
        #endif

        let body: [String: Any] = [
            "token": token,
            "environment": environment,
            "timezone": TimeZone.current.identifier,
            "notify_level": notifyLevel.rawValue,
            "digest_enabled": digestEnabled,
        ]

        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
            let (_, response) = try await URLSession.shared.data(for: request)
            if let http = response as? HTTPURLResponse {
                print("[push] registered with server: \(http.statusCode)")
            }
        } catch {
            print("[push] server registration error: \(error)")
        }
    }
}

// MARK: - UNUserNotificationCenterDelegate

extension PushManager: @preconcurrency UNUserNotificationCenterDelegate {
    /// Show notifications even when the app is in the foreground
    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        let id = notification.request.identifier
        let title = notification.request.content.title
        let body = notification.request.content.body
        let dealingId = notification.request.content.userInfo["dealing_id"] as? String
        await MainActor.run { self.recordRaw(id: id, title: title, body: body, dealingId: dealingId) }
        return [.banner, .sound, .badge]
    }

    /// Handle notification taps — route to the relevant dealing
    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse
    ) async {
        let userInfo = response.notification.request.content.userInfo

        if let dealingId = userInfo["dealing_id"] as? String {
            await MainActor.run {
                self.pendingDealingId = dealingId
            }
        }
    }
}
