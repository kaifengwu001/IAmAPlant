import XCTest
@testable import DailyRings

final class DateBoundaryTests: XCTestCase {
    // MARK: - Logical Date

    func testLogicalDate_beforeBoundary_returnsPreviousDay() {
        let calendar = Calendar.current
        // 2 AM on March 15 should belong to March 14
        let date = calendar.date(from: DateComponents(year: 2026, month: 3, day: 15, hour: 2, minute: 0))!
        let logical = DateBoundary.logicalDate(for: date, boundaryHour: 4)
        let components = calendar.dateComponents([.year, .month, .day], from: logical)

        XCTAssertEqual(components.year, 2026)
        XCTAssertEqual(components.month, 3)
        XCTAssertEqual(components.day, 14)
    }

    func testLogicalDate_afterBoundary_returnsSameDay() {
        let calendar = Calendar.current
        // 5 AM on March 15 should belong to March 15
        let date = calendar.date(from: DateComponents(year: 2026, month: 3, day: 15, hour: 5, minute: 0))!
        let logical = DateBoundary.logicalDate(for: date, boundaryHour: 4)
        let components = calendar.dateComponents([.year, .month, .day], from: logical)

        XCTAssertEqual(components.year, 2026)
        XCTAssertEqual(components.month, 3)
        XCTAssertEqual(components.day, 15)
    }

    func testLogicalDate_atExactBoundary_returnsSameDay() {
        let calendar = Calendar.current
        let date = calendar.date(from: DateComponents(year: 2026, month: 3, day: 15, hour: 4, minute: 0))!
        let logical = DateBoundary.logicalDate(for: date, boundaryHour: 4)
        let components = calendar.dateComponents([.year, .month, .day], from: logical)

        XCTAssertEqual(components.month, 3)
        XCTAssertEqual(components.day, 15)
    }

    func testLogicalDate_midnight_returnsPreviousDay() {
        let calendar = Calendar.current
        let date = calendar.date(from: DateComponents(year: 2026, month: 3, day: 15, hour: 0, minute: 0))!
        let logical = DateBoundary.logicalDate(for: date, boundaryHour: 4)
        let components = calendar.dateComponents([.year, .month, .day], from: logical)

        XCTAssertEqual(components.day, 14)
    }

    // MARK: - Date String

    func testDateString_roundTrip() {
        let calendar = Calendar.current
        let date = calendar.date(from: DateComponents(year: 2026, month: 1, day: 5))!
        let str = DateBoundary.dateString(from: date)
        XCTAssertEqual(str, "2026-01-05")

        let parsed = DateBoundary.date(from: str)
        XCTAssertNotNil(parsed)
    }

    // MARK: - Day Start / End

    func testDayStart_returnsCorrectBoundaryTime() {
        let calendar = Calendar.current
        let date = calendar.date(from: DateComponents(year: 2026, month: 6, day: 10))!
        let start = DateBoundary.dayStart(for: date, boundaryHour: 4)
        let components = calendar.dateComponents([.hour, .minute], from: start)

        XCTAssertEqual(components.hour, 4)
        XCTAssertEqual(components.minute, 0)
    }

    func testDayEnd_isNextDayBoundary() {
        let calendar = Calendar.current
        let date = calendar.date(from: DateComponents(year: 2026, month: 6, day: 10))!
        let end = DateBoundary.dayEnd(for: date, boundaryHour: 4)
        let components = calendar.dateComponents([.month, .day, .hour], from: end)

        XCTAssertEqual(components.day, 11)
        XCTAssertEqual(components.hour, 4)
    }
}
