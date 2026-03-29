import Foundation
import SwiftData

@Model
final class SleepSession {
    var sessionID: UUID
    var startTime: Date
    var endTime: Date?
    var isActive: Bool
    var source: SleepSource
    var screenMinutesDuringSleep: Int
    var validationNote: String?
    var createdAt: Date

    init(startTime: Date = .now, source: SleepSource = .manual) {
        self.sessionID = UUID()
        self.startTime = startTime
        self.isActive = true
        self.source = source
        self.screenMinutesDuringSleep = 0
        self.createdAt = .now
    }

    var durationHours: Double? {
        guard let endTime else { return nil }
        return endTime.timeIntervalSince(startTime) / 3600.0
    }

    var elapsedSinceStart: TimeInterval {
        Date.now.timeIntervalSince(startTime)
    }

    func ended(at endTime: Date = .now) -> SleepSession {
        let copy = SleepSession(startTime: startTime, source: source)
        copy.sessionID = sessionID
        copy.endTime = endTime
        copy.isActive = false
        copy.screenMinutesDuringSleep = screenMinutesDuringSleep
        copy.validationNote = validationNote
        copy.createdAt = createdAt
        return copy
    }
}
