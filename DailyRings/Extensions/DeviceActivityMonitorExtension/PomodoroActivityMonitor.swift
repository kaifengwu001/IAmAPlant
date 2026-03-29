import DeviceActivity
import Foundation

final class PomodoroActivityMonitor: DeviceActivityMonitor {
    private let storage = SharedPomodoroStorage.self

    override func intervalDidStart(for activity: DeviceActivityName) {
        guard let sessionID = UUID(uuidString: activity.rawValue) else { return }

        storage.saveEvent(PomodoroEvent(
            sessionID: sessionID,
            timestamp: .now,
            eventType: .started
        ))
    }

    override func intervalDidEnd(for activity: DeviceActivityName) {
        guard let sessionID = UUID(uuidString: activity.rawValue) else { return }

        storage.saveEvent(PomodoroEvent(
            sessionID: sessionID,
            timestamp: .now,
            eventType: .completed
        ))
    }

    override func eventDidReachThreshold(
        _ event: DeviceActivityEvent.Name,
        activity: DeviceActivityName
    ) {
        guard let sessionID = UUID(uuidString: activity.rawValue) else { return }

        storage.saveEvent(PomodoroEvent(
            sessionID: sessionID,
            timestamp: .now,
            eventType: .distractionDetected
        ))
    }
}
