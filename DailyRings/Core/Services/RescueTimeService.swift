import Foundation

actor RescueTimeService {
    private let supabaseService: SupabaseService

    init(supabaseService: SupabaseService) {
        self.supabaseService = supabaseService
    }

    /// Fetches productive and distracting minutes for a date via the Edge Function proxy.
    func fetchDailySummary(date: Date) async throws -> ProductivitySummary {
        let dateStr = DateBoundary.dateString(from: date)
        let response = try await supabaseService.fetchRescueTimeData(
            startDate: dateStr,
            endDate: dateStr,
            type: "daily_summary"
        )
        return ProductivitySummary(
            productiveMinutes: response.productive_minutes ?? 0,
            distractingMinutes: response.distracting_minutes ?? 0
        )
    }

    /// Fetches minute-level activity data for a time range (used for sleep validation).
    func fetchMinuteData(start: Date, end: Date) async throws -> [MinuteActivity] {
        let formatter = ISO8601DateFormatter()
        let response = try await supabaseService.fetchRescueTimeData(
            startDate: formatter.string(from: start),
            endDate: formatter.string(from: end),
            type: "minute_data"
        )

        guard let rows = response.rows else { return [] }
        return rows.compactMap { entries -> MinuteActivity? in
            guard let entry = entries.first else { return nil }
            return MinuteActivity(
                timestamp: entry.timestamp,
                seconds: entry.seconds,
                activity: entry.activity,
                productivity: entry.productivity
            )
        }
    }

    /// Finds gaps in activity that could indicate sleep or extended breaks.
    func findActivityGaps(date: Date, minGapHours: Double = AppConstants.rescueTimeMinActivityGapHours) async throws -> [DetectedGap] {
        let dateStr = DateBoundary.dateString(from: date)
        let response = try await supabaseService.fetchRescueTimeData(
            startDate: dateStr,
            endDate: dateStr,
            type: "activity_gaps"
        )

        guard let gaps = response.activity_gaps else { return [] }
        let formatter = ISO8601DateFormatter()
        return gaps.compactMap { gap -> DetectedGap? in
            guard let start = formatter.date(from: gap.start),
                  let end = formatter.date(from: gap.end) else { return nil }
            let durationHours = Double(gap.duration_minutes) / 60.0
            guard durationHours >= minGapHours else { return nil }
            return DetectedGap(start: start, end: end, durationMinutes: gap.duration_minutes)
        }
    }

    /// Validates a sleep window by checking for screen activity during it.
    func validateSleepWindow(start: Date, end: Date) async throws -> SleepValidation {
        let minuteData = try await fetchMinuteData(start: start, end: end)
        let totalScreenSeconds = minuteData.reduce(0) { $0 + $1.seconds }
        let screenMinutes = totalScreenSeconds / 60

        let (adjustedScore, note) = ScoreCalculator.validateSleep(
            rawScore: 1.0,
            screenMinutes: screenMinutes
        )

        return SleepValidation(
            screenMinutes: screenMinutes,
            scoreMultiplier: adjustedScore,
            note: note
        )
    }
}

struct ProductivitySummary {
    let productiveMinutes: Int
    let distractingMinutes: Int
}

struct MinuteActivity {
    let timestamp: String
    let seconds: Int
    let activity: String
    let productivity: Int
}

struct DetectedGap {
    let start: Date
    let end: Date
    let durationMinutes: Int

    var durationHours: Double {
        Double(durationMinutes) / 60.0
    }
}

struct SleepValidation {
    let screenMinutes: Int
    let scoreMultiplier: Double
    let note: String?
}
