import XCTest
@testable import DailyRings

final class ProductivityCalculatorTests: XCTestCase {
    func testCalculate_withAllSources() {
        let sessions = [
            makeSession(completed: true),
            makeSession(completed: true),
            makeSession(completed: false),
        ]

        let rtSummary = ProductivitySummary(productiveMinutes: 200, distractingMinutes: 60)
        let adjustments = [
            ManualAdjustment(minutes: 45, note: "Offline reading"),
        ]

        let result = ProductivityCalculator.calculate(
            sessions: sessions,
            rescueTimeSummary: rtSummary,
            manualAdjustments: adjustments,
            goalMinutes: 480
        )

        XCTAssertEqual(result.pomodoroCompletedCount, 2)
        XCTAssertEqual(result.pomodoroInterruptedCount, 1)
        XCTAssertEqual(result.pomodoroTotalMinutes, 50)
        XCTAssertEqual(result.rescueTimeProductiveMinutes, 200)
        XCTAssertEqual(result.overlapMinutes, 50) // min(50, 200)
        XCTAssertEqual(result.manualAdjustmentMinutes, 45)
        // total = 50 + 200 - 50 + 45 = 245
        XCTAssertEqual(result.totalProductiveMinutes, 245)
        XCTAssertGreaterThan(result.score, 0)
        XCTAssertLessThanOrEqual(result.score, 1.0)
    }

    func testCalculate_noSources() {
        let result = ProductivityCalculator.calculate(
            sessions: [],
            rescueTimeSummary: nil,
            manualAdjustments: [],
            goalMinutes: 480
        )

        XCTAssertEqual(result.totalProductiveMinutes, 0)
        XCTAssertEqual(result.score, 0)
    }

    private func makeSession(completed: Bool) -> PomodoroSession {
        let session = PomodoroSession(goalLabel: "Test", category: "Work", date: .now)
        if completed {
            session.isCompleted = true
            session.endTime = .now
            session.durationMinutes = 25
        } else {
            session.isCompleted = false
            session.endTime = .now
            session.durationMinutes = 10
        }
        return session
    }
}
