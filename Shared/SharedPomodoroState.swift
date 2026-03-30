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
    private static let debugLogKey = "pomodoroExtensionDebugLog"
    private static let foregroundKey = "pomodoroForegroundSeconds"
    private static let distractionLevelKey = "pomodoroDistractionLevel"
    private static let baselineKey = "pomodoroScreenTimeBaseline"
    private static let intervalStartKey = "pomodoroIntervalStartTime"

    // MARK: - Events

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

    // MARK: - Foreground Time (written by main app, read by extension)

    static func saveForegroundSeconds(_ seconds: Int) {
        userDefaults?.set(seconds, forKey: foregroundKey)
    }

    static func loadForegroundSeconds() -> Int {
        userDefaults?.integer(forKey: foregroundKey) ?? 0
    }

    // MARK: - Distraction Level (written by extension, read by main app)
    // 0 = none, 1 = warning (1 min), 2 = critical (2:30), 3 = fail (3 min)

    static func saveDistractionLevel(_ level: Int) {
        userDefaults?.set(level, forKey: distractionLevelKey)
    }

    static func loadDistractionLevel() -> Int {
        userDefaults?.integer(forKey: distractionLevelKey) ?? 0
    }

    // MARK: - Screen Time Baseline (written by extension)

    static func saveIntervalStartTime(_ date: Date) {
        userDefaults?.set(date.timeIntervalSince1970, forKey: intervalStartKey)
    }

    static func loadIntervalStartTime() -> Date? {
        let ts = userDefaults?.double(forKey: intervalStartKey) ?? 0
        return ts > 0 ? Date(timeIntervalSince1970: ts) : nil
    }

    static func saveScreenTimeBaseline(_ seconds: Int) {
        userDefaults?.set(seconds, forKey: baselineKey)
    }

    static func loadScreenTimeBaseline() -> Int {
        userDefaults?.integer(forKey: baselineKey) ?? 0
    }

    // MARK: - Session Reset

    static func clearSessionData() {
        userDefaults?.removeObject(forKey: "pomodoroEvents")
        userDefaults?.removeObject(forKey: foregroundKey)
        userDefaults?.removeObject(forKey: distractionLevelKey)
        userDefaults?.removeObject(forKey: baselineKey)
        userDefaults?.removeObject(forKey: intervalStartKey)
    }

    // MARK: - Extension Debug Log

    static func appendExtensionLog(_ message: String) {
        var log = loadExtensionLog()
        let fmt = DateFormatter()
        fmt.dateFormat = "HH:mm:ss"
        log.append("[\(fmt.string(from: .now))] \(message)")
        if log.count > 30 { log.removeFirst() }
        userDefaults?.set(log, forKey: debugLogKey)
    }

    static func loadExtensionLog() -> [String] {
        userDefaults?.stringArray(forKey: debugLogKey) ?? []
    }

    static func clearExtensionLog() {
        userDefaults?.removeObject(forKey: debugLogKey)
    }
}

struct PomodoroEvent: Codable {
    let sessionID: UUID
    let timestamp: Date
    let eventType: EventType
    let durationSeconds: Int

    init(
        sessionID: UUID,
        timestamp: Date,
        eventType: EventType,
        durationSeconds: Int = 0
    ) {
        self.sessionID = sessionID
        self.timestamp = timestamp
        self.eventType = eventType
        self.durationSeconds = durationSeconds
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        sessionID = try container.decode(UUID.self, forKey: .sessionID)
        timestamp = try container.decode(Date.self, forKey: .timestamp)
        eventType = try container.decode(EventType.self, forKey: .eventType)
        durationSeconds = try container.decodeIfPresent(Int.self, forKey: .durationSeconds) ?? 0
    }

    enum EventType: String, Codable {
        case started
        case completed
        case screenTimeThreshold
        case distractionDetected
        case interrupted
    }
}
