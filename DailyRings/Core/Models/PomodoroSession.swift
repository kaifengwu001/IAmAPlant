import Foundation
import SwiftData

@Model
final class PomodoroSession {
    var sessionID: UUID
    var date: Date
    var dateString: String
    var goalLabel: String
    var category: String
    var startTime: Date
    var endTime: Date?
    var isCompleted: Bool
    var distractedSeconds: Int
    var durationMinutes: Int
    var createdAt: Date
    var supabaseID: String?

    init(
        goalLabel: String,
        category: String,
        date: Date
    ) {
        self.sessionID = UUID()
        self.date = date
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        self.dateString = formatter.string(from: date)
        self.goalLabel = goalLabel
        self.category = category
        self.startTime = .now
        self.isCompleted = false
        self.distractedSeconds = 0
        self.durationMinutes = 0
        self.createdAt = .now
    }

    func completed(distractedSeconds: Int) -> PomodoroSession {
        let copy = PomodoroSession(goalLabel: goalLabel, category: category, date: date)
        copy.sessionID = sessionID
        copy.dateString = dateString
        copy.startTime = startTime
        copy.endTime = .now
        copy.isCompleted = true
        copy.distractedSeconds = distractedSeconds
        copy.durationMinutes = AppConstants.pomodoroWorkMinutes
        copy.createdAt = createdAt
        copy.supabaseID = supabaseID
        return copy
    }

    func interrupted(distractedSeconds: Int) -> PomodoroSession {
        let copy = PomodoroSession(goalLabel: goalLabel, category: category, date: date)
        copy.sessionID = sessionID
        copy.dateString = dateString
        copy.startTime = startTime
        copy.endTime = .now
        copy.isCompleted = false
        copy.distractedSeconds = distractedSeconds
        let elapsed = Date.now.timeIntervalSince(startTime)
        copy.durationMinutes = Int(elapsed / 60)
        copy.createdAt = createdAt
        copy.supabaseID = supabaseID
        return copy
    }
}
