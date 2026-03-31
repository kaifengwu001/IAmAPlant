import XCTest
@testable import DailyRings

final class ScoreCalculatorTests: XCTestCase {
    // MARK: - Sleep Score

    func testSleepScore_fullGoal_returns1() {
        let score = ScoreCalculator.sleepScore(hours: 8.0, goalHours: 8.0)
        XCTAssertEqual(score, 1.0, accuracy: 0.001)
    }

    func testSleepScore_halfGoal_returns05() {
        let score = ScoreCalculator.sleepScore(hours: 4.0, goalHours: 8.0)
        XCTAssertEqual(score, 0.5, accuracy: 0.001)
    }

    func testSleepScore_exceedsGoal_cappedAt1() {
        let score = ScoreCalculator.sleepScore(hours: 10.0, goalHours: 8.0)
        XCTAssertEqual(score, 1.0, accuracy: 0.001)
    }

    func testSleepScore_zeroGoal_returns0() {
        let score = ScoreCalculator.sleepScore(hours: 8.0, goalHours: 0)
        XCTAssertEqual(score, 0.0)
    }

    // MARK: - Exercise Score

    func testExerciseScore_atGoal() {
        let score = ScoreCalculator.exerciseScore(minutes: 30, goalMinutes: 30)
        XCTAssertEqual(score, 1.0, accuracy: 0.001)
    }

    func testExerciseScore_belowGoal() {
        let score = ScoreCalculator.exerciseScore(minutes: 15, goalMinutes: 30)
        XCTAssertEqual(score, 0.5, accuracy: 0.001)
    }

    // MARK: - Nutrition Score

    func testNutritionScore_average7_returns07() {
        let meals = [
            MealScore(timestamp: .now, score: 7, briefDescription: "test", photoFilename: "a.jpg"),
            MealScore(timestamp: .now, score: 7, briefDescription: "test", photoFilename: "b.jpg"),
        ]
        let score = ScoreCalculator.nutritionScore(mealScores: meals)
        XCTAssertEqual(score, 0.7, accuracy: 0.001)
    }

    func testNutritionScore_noMeals_returns0() {
        let score = ScoreCalculator.nutritionScore(mealScores: [])
        XCTAssertEqual(score, 0.0)
    }

    // MARK: - Productivity Score

    func testProductivityScore_deduplication() {
        let total = ScoreCalculator.productiveTotalMinutes(
            pomodoroCompletedSessions: 4,
            rescueTimeProductiveMinutes: 300,
            overlapMinutes: 100,
            manualAdjustmentMinutes: 30
        )
        // 4*25 + 300 - 100 + 30 = 100 + 300 - 100 + 30 = 330
        XCTAssertEqual(total, 330)
    }

    func testProductivityScore_neverNegative() {
        let total = ScoreCalculator.productiveTotalMinutes(
            pomodoroCompletedSessions: 0,
            rescueTimeProductiveMinutes: 10,
            overlapMinutes: 50,
            manualAdjustmentMinutes: -20
        )
        XCTAssertEqual(total, 0)
    }

    // MARK: - Sleep Validation

    func testSleepValidation_lowScreenTime_noAdjustment() {
        let (score, note) = ScoreCalculator.validateSleep(rawScore: 1.0, screenMinutes: 5)
        XCTAssertEqual(score, 1.0, accuracy: 0.001)
        XCTAssertNil(note)
    }

    func testSleepValidation_moderateScreenTime_noteButNoScoreChange() {
        let (score, note) = ScoreCalculator.validateSleep(rawScore: 1.0, screenMinutes: 20)
        XCTAssertEqual(score, 1.0, accuracy: 0.001)
        XCTAssertNotNil(note)
        XCTAssertTrue(note!.contains("20"))
    }

    func testSleepValidation_highScreenTime_scoreReduced() {
        let (score, _) = ScoreCalculator.validateSleep(rawScore: 1.0, screenMinutes: 60)
        XCTAssertLessThan(score, 1.0)
    }
}
