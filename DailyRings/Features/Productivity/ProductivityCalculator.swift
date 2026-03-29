import Foundation
import SwiftData

enum ProductivityCalculator {
    struct DailyProductivity {
        let pomodoroSessions: [PomodoroSession]
        let pomodoroCompletedCount: Int
        let pomodoroInterruptedCount: Int
        let pomodoroTotalMinutes: Int
        let rescueTimeProductiveMinutes: Int
        let rescueTimeDistractingMinutes: Int
        let overlapMinutes: Int
        let manualAdjustmentMinutes: Int
        let totalProductiveMinutes: Int
        let score: Double
    }

    static func calculate(
        sessions: [PomodoroSession],
        rescueTimeSummary: ProductivitySummary?,
        manualAdjustments: [ManualAdjustment],
        goalMinutes: Int
    ) -> DailyProductivity {
        let completed = sessions.filter(\.isCompleted)
        let interrupted = sessions.filter { !$0.isCompleted && $0.endTime != nil }

        let pomodoroMinutes = completed.count * AppConstants.pomodoroWorkMinutes
        let rtProductiveMinutes = rescueTimeSummary?.productiveMinutes ?? 0
        let rtDistractingMinutes = rescueTimeSummary?.distractingMinutes ?? 0

        // Conservative overlap: assume all Pomodoro time was tracked by RescueTime
        let overlap = min(pomodoroMinutes, rtProductiveMinutes)

        let manualNet = manualAdjustments.reduce(0) { $0 + $1.minutes }

        let total = ScoreCalculator.productiveTotalMinutes(
            pomodoroCompletedSessions: completed.count,
            rescueTimeProductiveMinutes: rtProductiveMinutes,
            overlapMinutes: overlap,
            manualAdjustmentMinutes: manualNet
        )

        let score = ScoreCalculator.productivityScore(
            pomodoroCompletedSessions: completed.count,
            rescueTimeProductiveMinutes: rtProductiveMinutes,
            overlapMinutes: overlap,
            manualAdjustmentMinutes: manualNet,
            goalMinutes: goalMinutes
        )

        return DailyProductivity(
            pomodoroSessions: sessions,
            pomodoroCompletedCount: completed.count,
            pomodoroInterruptedCount: interrupted.count,
            pomodoroTotalMinutes: pomodoroMinutes,
            rescueTimeProductiveMinutes: rtProductiveMinutes,
            rescueTimeDistractingMinutes: rtDistractingMinutes,
            overlapMinutes: overlap,
            manualAdjustmentMinutes: manualNet,
            totalProductiveMinutes: total,
            score: score
        )
    }
}
