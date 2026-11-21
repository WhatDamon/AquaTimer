import AppKit
@preconcurrency import UserNotifications
import OSLog

@MainActor
final class NotificationService {
    static let shared = NotificationService()
    private let center = UNUserNotificationCenter.current()
    private let logger = Logger(subsystem: "dev.aquatimer.AquaTimer", category: "Notifications")
    private var delivery: Task<Void, Never>?
    private var requestID: String?

    private init() {
        NotificationCenter.default.addObserver(self, selector: #selector(settingsChanged),
                                               name: AppSettings.didChange, object: AppSettings.shared)
    }

    func authorizationStatus() async -> UNAuthorizationStatus {
        await center.notificationSettings().authorizationStatus
    }

    func requestPermission() async throws -> Bool {
        let status = await authorizationStatus()
        if status == .authorized || status == .provisional { return true }
        guard status == .notDetermined else { return false }
        return try await center.requestAuthorization(options: [.alert])
    }

    func postCompletionIfNeeded() {
        cancelCompletion()
        guard AppSettings.shared.notificationsEnabled, !NSApp.isActive else { return }
        let id = "AquaTimer.Finished." + UUID().uuidString
        requestID = id
        delivery = Task { [weak self] in
            guard let self else { return }
            let status = await authorizationStatus()
            guard !Task.isCancelled, requestID == id,
                  AppSettings.shared.notificationsEnabled, !NSApp.isActive,
                  status == .authorized || status == .provisional else { return }
            let content = UNMutableNotificationContent()
            content.title = "时间到"
            content.body = "AquaTimer 倒计时已结束。"
            // Audio is controlled separately by the user's sound/volume preferences.
            let request = UNNotificationRequest(identifier: id, content: content, trigger: nil)
            do {
                try await center.add(request)
                if Task.isCancelled || requestID != id { remove(id) }
            } catch {
                logger.error("Completion notification failed: \(error.localizedDescription, privacy: .public)")
            }
        }
    }

    func cancelCompletion() {
        delivery?.cancel()
        delivery = nil
        if let requestID { remove(requestID) }
        requestID = nil
    }

    private func remove(_ id: String) {
        center.removePendingNotificationRequests(withIdentifiers: [id])
        center.removeDeliveredNotifications(withIdentifiers: [id])
    }

    @objc private func settingsChanged() {
        if !AppSettings.shared.notificationsEnabled { cancelCompletion() }
    }
}
