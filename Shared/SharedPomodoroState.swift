import Foundation

enum SharedPomodoroStorage {
    private static let userDefaults = UserDefaults(suiteName: AppConstants.appGroupID)
    private static let debugLogKey = "pomodoroExtensionDebugLog"
    private static let distractionLevelKey = "pomodoroDistractionLevel"

    // MARK: - Distraction Level (written by extension, read by main app)
    // 0 = none, 1 = warning (1 min), 2 = critical (2:30), 3 = fail (3 min)

    static func saveDistractionLevel(_ level: Int) {
        userDefaults?.set(level, forKey: distractionLevelKey)
    }

    static func loadDistractionLevel() -> Int {
        userDefaults?.integer(forKey: distractionLevelKey) ?? 0
    }

    // MARK: - Session Reset

    static func clearSessionData() {
        userDefaults?.removeObject(forKey: distractionLevelKey)
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
