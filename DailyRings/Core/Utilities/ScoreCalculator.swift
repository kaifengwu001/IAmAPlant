import Foundation

enum ScoreCalculator {
    static func sleepScore(hours: Double, goalHours: Double) -> Double {
        guard goalHours > 0 else { return 0 }
        return min(hours / goalHours, 1.0)
    }

    static func exerciseScore(minutes: Int, goalMinutes: Int) -> Double {
        guard goalMinutes > 0 else { return 0 }
        return min(Double(minutes) / Double(goalMinutes), 1.0)
    }

    static let nutritionRingClosesAt: Double = 8.0

    static func nutritionScore(mealScores: [MealScore]) -> Double {
        guard !mealScores.isEmpty else { return 0 }
        let average = mealScores.map(\.score).reduce(0, +) / Double(mealScores.count)
        return min(average / nutritionRingClosesAt, 1.0)
    }

    static func nutritionAverage(mealScores: [MealScore]) -> Double {
        guard !mealScores.isEmpty else { return 0 }
        return mealScores.map(\.score).reduce(0, +) / Double(mealScores.count)
    }

    static func productivityScore(
        pomodoroCompletedSessions: Int,
        rescueTimeProductiveMinutes: Int,
        overlapMinutes: Int,
        manualAdjustmentMinutes: Int,
        goalMinutes: Int
    ) -> Double {
        guard goalMinutes > 0 else { return 0 }
        let total = productiveTotalMinutes(
            pomodoroCompletedSessions: pomodoroCompletedSessions,
            rescueTimeProductiveMinutes: rescueTimeProductiveMinutes,
            overlapMinutes: overlapMinutes,
            manualAdjustmentMinutes: manualAdjustmentMinutes
        )
        return min(Double(total) / Double(goalMinutes), 1.0)
    }

    static func productiveTotalMinutes(
        pomodoroCompletedSessions: Int,
        rescueTimeProductiveMinutes: Int,
        overlapMinutes: Int,
        manualAdjustmentMinutes: Int
    ) -> Int {
        let pomodoroMinutes = pomodoroCompletedSessions * AppConstants.pomodoroWorkMinutes
        let total = pomodoroMinutes + rescueTimeProductiveMinutes - overlapMinutes + manualAdjustmentMinutes
        return max(total, 0)
    }

    /// Validates sleep by checking screen time during the declared sleep window.
    /// Returns a tuple of (adjustedScore, validationNote).
    static func validateSleep(
        rawScore: Double,
        screenMinutes: Int
    ) -> (score: Double, note: String?) {
        if screenMinutes < AppConstants.sleepScreenTimeThresholdMinor {
            return (rawScore, nil)
        } else if screenMinutes < AppConstants.sleepScreenTimeThresholdMajor {
            return (rawScore, "You had \(screenMinutes) min of screen time during sleep")
        } else {
            let penalty = Double(screenMinutes - AppConstants.sleepScreenTimeThresholdMajor) / 60.0
            let adjusted = max(rawScore - penalty * 0.1, 0)
            return (adjusted, "High screen time (\(screenMinutes) min) during sleep — score adjusted")
        }
    }
}
