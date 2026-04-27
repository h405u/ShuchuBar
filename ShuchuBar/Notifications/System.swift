import UserNotifications

class SystemNotifyHelper: NSObject, UNUserNotificationCenterDelegate {
    private let center = UNUserNotificationCenter.current()

    override init() {
        super.init()
        center.delegate = self
    }

    func requestPermissionIfNeeded() {
        center.getNotificationSettings { settings in
            guard settings.authorizationStatus == .notDetermined else { return }
            self.center.requestAuthorization(options: [.alert, .sound]) { _, _ in }
        }
    }

    func userNotificationCenter(
        _: UNUserNotificationCenter,
        willPresent _: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        if #available(macOS 11.0, *) {
            completionHandler([.banner, .sound])
        } else {
            completionHandler([.alert, .sound])
        }
    }

    func sessionStarted() {
        send(title: "Session started", body: "Focus session is running.")
    }

    func focusTimeUp() {
        send(title: "Focus time is up", body: "Timer is in overtime.")
    }

    func sessionEnded() {
        send(title: "Session ended", body: "Focus session ended.")
    }

    func breakStarted() {
        send(title: "Break started", body: "Take your break.")
    }

    func breakEnded() {
        send(title: "Break ended", body: "Break finished.")
    }

    private func send(title: String, body: String) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        if #available(macOS 12.0, *) {
            content.interruptionLevel = .timeSensitive
        }
        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: nil
        )
        center.add(request)
    }
}
