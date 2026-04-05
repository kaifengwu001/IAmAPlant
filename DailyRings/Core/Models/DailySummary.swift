import Foundation
import SwiftData

@Model
final class DailySummary {
    @Attribute(.unique) var dateString: String
    var date: Date
    var timezone: String

    // Sleep
    var sleepStart: Date?
    var sleepEnd: Date?
    var sleepHours: Double
    var sleepScore: Double
    var sleepScreenMinutes: Int
    var sleepSourceRaw: String

    // Exercise
    var exerciseMinutes: Int
    var exerciseScore: Double

    // Nutrition
    var nutritionScore: Double
    var mealCount: Int
    var mealScoresData: Data?

    // Productivity
    var pomodoroCompleted: Int
    var pomodoroInterrupted: Int
    var pomodoroTotalMinutes: Int
    var rescueTimeProductiveMinutes: Int
    var rescueTimeDistractingMinutes: Int
    var overlapMinutes: Int
    var manualAdjustmentMinutes: Int
    var manualAdjustmentsData: Data?
    var productiveMinutesTotal: Int
    var productivityScore: Double

    // Metadata
    var statusRaw: String
    var createdAt: Date
    var supabaseID: String?

    init(date: Date, timezone: String = TimeZone.current.identifier) {
        self.dateString = DateBoundary.dateString(from: date)
        self.date = date
        self.timezone = timezone

        self.sleepHours = 0
        self.sleepScore = 0
        self.sleepScreenMinutes = 0
        self.sleepSourceRaw = SleepSource.manual.rawValue

        self.exerciseMinutes = 0
        self.exerciseScore = 0

        self.nutritionScore = 0
        self.mealCount = 0

        self.pomodoroCompleted = 0
        self.pomodoroInterrupted = 0
        self.pomodoroTotalMinutes = 0
        self.rescueTimeProductiveMinutes = 0
        self.rescueTimeDistractingMinutes = 0
        self.overlapMinutes = 0
        self.manualAdjustmentMinutes = 0
        self.productiveMinutesTotal = 0
        self.productivityScore = 0

        self.statusRaw = SyncStatus.partial.rawValue
        self.createdAt = .now
    }

    @Transient
    var sleepSource: SleepSource {
        get { SleepSource(rawValue: sleepSourceRaw) ?? .manual }
        set { sleepSourceRaw = newValue.rawValue }
    }

    @Transient
    var status: SyncStatus {
        get { SyncStatus(rawValue: statusRaw) ?? .partial }
        set { statusRaw = newValue.rawValue }
    }

    var mealScores: [MealScore] {
        get {
            guard let data = mealScoresData else { return [] }
            return (try? JSONDecoder().decode([MealScore].self, from: data)) ?? []
        }
        set {
            mealScoresData = try? JSONEncoder().encode(newValue)
            status = .partial
        }
    }

    var manualAdjustments: [ManualAdjustment] {
        get {
            guard let data = manualAdjustmentsData else { return [] }
            return (try? JSONDecoder().decode([ManualAdjustment].self, from: data)) ?? []
        }
        set {
            manualAdjustmentsData = try? JSONEncoder().encode(newValue)
            status = .partial
        }
    }

    var scores: [Double] {
        [sleepScore, exerciseScore, nutritionScore, productivityScore]
    }
}

enum SleepSource: String, Codable {
    case manual
    case autoDetected = "auto_detected"
    case healthkit
}

enum SyncStatus: String, Codable {
    case partial
    case complete
    case synced
}

extension DailySummary {
    static func fetchOrCreate(for date: Date, in modelContext: ModelContext) throws -> DailySummary {
        let normalizedDate = Calendar.current.startOfDay(for: date)
        let dateString = DateBoundary.dateString(from: normalizedDate)
        let descriptor = FetchDescriptor<DailySummary>(
            predicate: #Predicate { $0.dateString == dateString }
        )

        if let existing = try modelContext.fetch(descriptor).first {
            return existing
        }

        let summary = DailySummary(date: normalizedDate)
        modelContext.insert(summary)
        return summary
    }

    func updateExercise(minutes: Int, goalMinutes: Int = AppConstants.defaultExerciseGoalMinutes) {
        exerciseMinutes = minutes
        exerciseScore = ScoreCalculator.exerciseScore(minutes: minutes, goalMinutes: goalMinutes)
        status = .partial
    }

    func applyProductivity(_ productivity: ProductivityCalculator.DailyProductivity) {
        pomodoroCompleted = productivity.pomodoroCompletedCount
        pomodoroInterrupted = productivity.pomodoroInterruptedCount
        pomodoroTotalMinutes = productivity.pomodoroTotalMinutes
        rescueTimeProductiveMinutes = productivity.rescueTimeProductiveMinutes
        rescueTimeDistractingMinutes = productivity.rescueTimeDistractingMinutes
        overlapMinutes = productivity.overlapMinutes
        manualAdjustmentMinutes = productivity.manualAdjustmentMinutes
        productiveMinutesTotal = productivity.totalProductiveMinutes
        productivityScore = productivity.score
        status = .partial
    }

    @discardableResult
    static func refreshProductivity(
        for date: Date,
        in modelContext: ModelContext,
        rescueTimeSummary: ProductivitySummary? = nil,
        goalMinutes: Int = AppConstants.defaultProductivityGoalMinutes
    ) throws -> DailySummary {
        let normalizedDate = Calendar.current.startOfDay(for: date)
        let dateString = DateBoundary.dateString(from: normalizedDate)
        let summary = try fetchOrCreate(for: normalizedDate, in: modelContext)

        let sessionDescriptor = FetchDescriptor<PomodoroSession>(
            predicate: #Predicate { $0.dateString == dateString }
        )
        let sessions = try modelContext.fetch(sessionDescriptor)

        let effectiveRescueTimeSummary = rescueTimeSummary ?? ProductivitySummary(
            productiveMinutes: summary.rescueTimeProductiveMinutes,
            distractingMinutes: summary.rescueTimeDistractingMinutes
        )

        let productivity = ProductivityCalculator.calculate(
            sessions: sessions,
            rescueTimeSummary: effectiveRescueTimeSummary,
            manualAdjustments: summary.manualAdjustments,
            goalMinutes: goalMinutes
        )

        summary.applyProductivity(productivity)
        return summary
    }
}

struct MealScore: Codable, Identifiable {
    let id: UUID
    let timestamp: Date
    let score: Double
    let briefDescription: String
    let photoFilename: String

    init(timestamp: Date, score: Double, briefDescription: String, photoFilename: String) {
        self.id = UUID()
        self.timestamp = timestamp
        self.score = score
        self.briefDescription = briefDescription
        self.photoFilename = photoFilename
    }

    var timeLabel: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        return formatter.string(from: timestamp)
    }

    private enum CodingKeys: String, CodingKey {
        case id, timestamp, score, briefDescription, photoFilename
        case mealType
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        timestamp = try container.decode(Date.self, forKey: .timestamp)
        score = try container.decode(Double.self, forKey: .score)
        briefDescription = try container.decode(String.self, forKey: .briefDescription)
        photoFilename = try container.decode(String.self, forKey: .photoFilename)
        _ = try? container.decode(String.self, forKey: .mealType)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(timestamp, forKey: .timestamp)
        try container.encode(score, forKey: .score)
        try container.encode(briefDescription, forKey: .briefDescription)
        try container.encode(photoFilename, forKey: .photoFilename)
    }
}

struct ManualAdjustment: Codable, Identifiable {
    let id: UUID
    let minutes: Int
    let note: String
    let timestamp: Date

    init(minutes: Int, note: String, timestamp: Date = .now) {
        self.id = UUID()
        self.minutes = minutes
        self.note = note
        self.timestamp = timestamp
    }
}
