import Foundation

struct SharedPomodoroState: Codable {
    let sessionID: UUID
    let startTime: Date
    let endTime: Date
    let distractedSeconds: Int
    let isCompleted: Bool
    let wasInterrupted: Bool
}

enum SharedPomodoroStorage {
    private static let userDefaults = UserDefaults(suiteName: AppConstants.appGroupID)

    static func saveEvent(_ event: PomodoroEvent) {
        var events = loadEvents()
        events.append(event)
        guard let data = try? JSONEncoder().encode(events) else { return }
        userDefaults?.set(data, forKey: "pomodoroEvents")
    }

    static func loadEvents() -> [PomodoroEvent] {
        guard let data = userDefaults?.data(forKey: "pomodoroEvents"),
              let events = try? JSONDecoder().decode([PomodoroEvent].self, from: data) else {
            return []
        }
        return events
    }

    static func clearEvents() {
        userDefaults?.removeObject(forKey: "pomodoroEvents")
    }
}

struct PomodoroEvent: Codable {
    let sessionID: UUID
    let timestamp: Date
    let eventType: EventType

    enum EventType: String, Codable {
        case started
        case completed
        case distractionDetected
        case interrupted
    }
}
