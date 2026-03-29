import Foundation

enum DateBoundary {
    /// Returns the "logical day" for a given timestamp using the configured day boundary hour.
    /// E.g., if boundary is 4 AM, then 2 AM on March 15 belongs to March 14's logical day.
    static func logicalDate(for timestamp: Date, boundaryHour: Int = AppConstants.defaultDayBoundaryHour) -> Date {
        let calendar = Calendar.current
        let hour = calendar.component(.hour, from: timestamp)

        let referenceDate: Date
        if hour < boundaryHour {
            referenceDate = calendar.date(byAdding: .day, value: -1, to: timestamp) ?? timestamp
        } else {
            referenceDate = timestamp
        }

        return calendar.startOfDay(for: referenceDate)
    }

    /// Returns the start of the logical day (boundary hour on that calendar day).
    static func dayStart(for date: Date, boundaryHour: Int = AppConstants.defaultDayBoundaryHour) -> Date {
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: date)
        return calendar.date(bySettingHour: boundaryHour, minute: 0, second: 0, of: startOfDay) ?? startOfDay
    }

    /// Returns the end of the logical day (boundary hour on the next calendar day).
    static func dayEnd(for date: Date, boundaryHour: Int = AppConstants.defaultDayBoundaryHour) -> Date {
        let calendar = Calendar.current
        guard let nextDay = calendar.date(byAdding: .day, value: 1, to: date) else { return date }
        return dayStart(for: nextDay, boundaryHour: boundaryHour)
    }

    /// Format a date as "yyyy-MM-dd" for use as a key.
    static func dateString(from date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }

    /// Parse a "yyyy-MM-dd" string back to a Date.
    static func date(from string: String) -> Date? {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.date(from: string)
    }

    /// Returns today's logical date.
    static func today(boundaryHour: Int = AppConstants.defaultDayBoundaryHour) -> Date {
        logicalDate(for: .now, boundaryHour: boundaryHour)
    }

    /// Returns the logical date for yesterday.
    static func yesterday(boundaryHour: Int = AppConstants.defaultDayBoundaryHour) -> Date {
        let todayDate = today(boundaryHour: boundaryHour)
        return Calendar.current.date(byAdding: .day, value: -1, to: todayDate) ?? todayDate
    }
}
