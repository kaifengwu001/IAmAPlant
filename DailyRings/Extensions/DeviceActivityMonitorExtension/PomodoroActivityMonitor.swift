import DeviceActivity
import Foundation
import UserNotifications

final class PomodoroActivityMonitor: DeviceActivityMonitor {
    private let storage = SharedPomodoroStorage.self
    private let baselineGraceSeconds: TimeInterval = 10

    override init() {
        super.init()
        storage.appendExtensionLog("Extension loaded (init)")
    }

    override func intervalDidStart(for activity: DeviceActivityName) {
        storage.appendExtensionLog("intervalDidStart: \(activity.rawValue.prefix(8))")
        storage.saveIntervalStartTime(.now)
        storage.saveScreenTimeBaseline(0)
        storage.saveDistractionLevel(0)

        guard let sessionID = UUID(uuidString: activity.rawValue) else {
            storage.appendExtensionLog("ERROR: invalid UUID from activity name")
            return
        }

        storage.saveEvent(PomodoroEvent(
            sessionID: sessionID,
            timestamp: .now,
            eventType: .started
        ))
    }

    override func intervalDidEnd(for activity: DeviceActivityName) {
        storage.appendExtensionLog("intervalDidEnd: \(activity.rawValue.prefix(8))")

        guard let sessionID = UUID(uuidString: activity.rawValue) else { return }

        storage.saveEvent(PomodoroEvent(
            sessionID: sessionID,
            timestamp: .now,
            eventType: .completed
        ))
    }

    override func intervalWillStartWarning(for activity: DeviceActivityName) {
        storage.appendExtensionLog("intervalWillStartWarning: \(activity.rawValue.prefix(8))")
    }

    override func intervalWillEndWarning(for activity: DeviceActivityName) {
        storage.appendExtensionLog("intervalWillEndWarning: \(activity.rawValue.prefix(8))")
    }

    override func eventDidReachThreshold(
        _ event: DeviceActivityEvent.Name,
        activity: DeviceActivityName
    ) {
        guard let sessionID = UUID(uuidString: activity.rawValue) else { return }

        let thresholdSeconds = parseThresholdSeconds(from: event.rawValue)
        let intervalStart = storage.loadIntervalStartTime() ?? .distantPast
        let secondsSinceStart = Date.now.timeIntervalSince(intervalStart)

        if secondsSinceStart < baselineGraceSeconds {
            let currentBaseline = storage.loadScreenTimeBaseline()
            let newBaseline = max(currentBaseline, thresholdSeconds)
            storage.saveScreenTimeBaseline(newBaseline)
            storage.appendExtensionLog("BASE T\(thresholdSeconds)s → baseline=\(newBaseline)s")
            return
        }

        let baseline = storage.loadScreenTimeBaseline()
        let newScreenTime = max(0, thresholdSeconds - baseline)
        let foregroundSeconds = storage.loadForegroundSeconds()
        let adjustedDistraction = max(0, newScreenTime - foregroundSeconds)
        let currentLevel = storage.loadDistractionLevel()

        storage.appendExtensionLog(
            "T\(thresholdSeconds)s base=\(baseline)s new=\(newScreenTime)s fg=\(foregroundSeconds)s adj=\(adjustedDistraction)s lvl=\(currentLevel)"
        )

        storage.saveEvent(PomodoroEvent(
            sessionID: sessionID,
            timestamp: .now,
            eventType: .screenTimeThreshold,
            durationSeconds: thresholdSeconds
        ))

        if adjustedDistraction >= 180, currentLevel < 3 {
            storage.saveDistractionLevel(3)
            scheduleNotification(
                id: "pomodoro_fail_\(sessionID.uuidString)",
                title: "Session Failed",
                body: "3 minutes on phone. Pomodoro session FAILED."
            )
        } else if adjustedDistraction >= 150, currentLevel < 2 {
            storage.saveDistractionLevel(2)
            scheduleNotification(
                id: "pomodoro_warn2_\(sessionID.uuidString)",
                title: "Distraction Warning",
                body: "2:30 on phone — session fails at 3 minutes!"
            )
        } else if adjustedDistraction >= 60, currentLevel < 1 {
            storage.saveDistractionLevel(1)
            scheduleNotification(
                id: "pomodoro_warn1_\(sessionID.uuidString)",
                title: "Distraction Warning",
                body: "You've been on your phone for 1 minute. Put it down!"
            )
        }
    }

    override func eventWillReachThresholdWarning(
        _ event: DeviceActivityEvent.Name,
        activity: DeviceActivityName
    ) {
        storage.appendExtensionLog("thresholdWarning: \(event.rawValue.prefix(24))")
    }

    private func parseThresholdSeconds(from rawValue: String) -> Int {
        guard rawValue.hasPrefix("t"),
              let underscoreIdx = rawValue.firstIndex(of: "_"),
              let seconds = Int(rawValue[rawValue.index(after: rawValue.startIndex)..<underscoreIdx])
        else { return 0 }
        return seconds
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
