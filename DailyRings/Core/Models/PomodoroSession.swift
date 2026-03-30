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
        self.dateString = DateBoundary.dateString(from: date)
        self.goalLabel = goalLabel
        self.category = category
        self.startTime = .now
        self.isCompleted = false
        self.distractedSeconds = 0
        self.durationMinutes = 0
        self.createdAt = .now
    }

    func markCompleted(distractedSeconds: Int) {
        self.endTime = .now
        self.isCompleted = true
        self.distractedSeconds = distractedSeconds
        self.durationMinutes = AppConstants.pomodoroWorkMinutes
    }

    func markInterrupted(distractedSeconds: Int) {
        self.endTime = .now
        self.isCompleted = false
        self.distractedSeconds = distractedSeconds
        let elapsed = Date.now.timeIntervalSince(startTime)
        self.durationMinutes = max(1, Int(elapsed / 60))
    }
}
