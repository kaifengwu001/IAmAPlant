import DeviceActivity
import Foundation
import UserNotifications

final class PomodoroActivityMonitor: DeviceActivityMonitor {
    private let storage = SharedPomodoroStorage.self

    override func intervalDidStart(for activity: DeviceActivityName) {
        storage.appendExtensionLog("intervalDidStart: \(activity.rawValue.prefix(8))")
        storage.saveDistractionLevel(0)
    }

    override func intervalDidEnd(for activity: DeviceActivityName) {
        storage.appendExtensionLog("intervalDidEnd: \(activity.rawValue.prefix(8))")
    }

    override func eventDidReachThreshold(
        _ event: DeviceActivityEvent.Name,
        activity: DeviceActivityName
    ) {
        guard let sessionID = UUID(uuidString: activity.rawValue) else {
            storage.appendExtensionLog("ERROR: invalid activity UUID")
            return
        }

        let raw = event.rawValue
        let currentLevel = storage.loadDistractionLevel()

        storage.appendExtensionLog("threshold: \(raw.prefix(24)) lvl=\(currentLevel)")

        if raw.hasPrefix("warn1_"), currentLevel < 1 {
            storage.saveDistractionLevel(1)
            scheduleNotification(
                id: "pomodoro_warn1_\(sessionID.uuidString)",
                title: "Distraction Warning",
                body: "You've been on your phone for 1 minute. Put it down!"
            )
        } else if raw.hasPrefix("warn2_"), currentLevel < 2 {
            storage.saveDistractionLevel(2)
            scheduleNotification(
                id: "pomodoro_warn2_\(sessionID.uuidString)",
                title: "Distraction Warning",
                body: "2:30 on phone — session fails at 3 minutes!"
            )
        } else if raw.hasPrefix("fail_"), currentLevel < 3 {
            storage.saveDistractionLevel(3)
            scheduleNotification(
                id: "pomodoro_fail_\(sessionID.uuidString)",
                title: "Session Failed",
                body: "3 minutes on phone. Pomodoro session FAILED."
            )
        }
    }

    override func intervalWillStartWarning(for activity: DeviceActivityName) {
        storage.appendExtensionLog("intervalWillStartWarning: \(activity.rawValue.prefix(8))")
    }

    override func intervalWillEndWarning(for activity: DeviceActivityName) {
        storage.appendExtensionLog("intervalWillEndWarning: \(activity.rawValue.prefix(8))")
    }

    override func eventWillReachThresholdWarning(
        _ event: DeviceActivityEvent.Name,
        activity: DeviceActivityName
    ) {
        storage.appendExtensionLog("thresholdWarning: \(event.rawValue.prefix(24))")
    }

    private func scheduleNotification(id: String, title: String, body: String) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: id,
            content: content,
            trigger: nil
        )

        UNUserNotificationCenter.current().add(request) { [self] error in
            if let error {
                storage.appendExtensionLog("Notif error: \(error.localizedDescription)")
            } else {
                storage.appendExtensionLog("Notif sent: \(title)")
            }
        }
    }
}
