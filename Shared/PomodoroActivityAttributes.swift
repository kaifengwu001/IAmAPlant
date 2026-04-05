import ActivityKit
import Foundation

struct PomodoroActivityAttributes: ActivityAttributes {
    let goalLabel: String
    let category: String
    let totalSeconds: Int

    struct ContentState: Codable, Hashable {
        let remainingSeconds: Int
        let endTime: Date
        let distractionLevel: Int
        let phase: Phase
    }

    enum Phase: String, Codable, Hashable {
        case running
        case completed
        case failed
        case cancelled
    }
}
