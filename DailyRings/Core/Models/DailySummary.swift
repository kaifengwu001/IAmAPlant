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
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        self.dateString = formatter.string(from: date)
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
        }
    }

    var manualAdjustments: [ManualAdjustment] {
        get {
            guard let data = manualAdjustmentsData else { return [] }
            return (try? JSONDecoder().decode([ManualAdjustment].self, from: data)) ?? []
        }
        set {
            manualAdjustmentsData = try? JSONEncoder().encode(newValue)
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

struct MealScore: Codable, Identifiable {
    let id: UUID
    let timestamp: Date
    let mealType: String
    let score: Double
    let briefDescription: String
    let photoFilename: String

    init(timestamp: Date, mealType: String, score: Double, briefDescription: String, photoFilename: String) {
        self.id = UUID()
        self.timestamp = timestamp
        self.mealType = mealType
        self.score = score
        self.briefDescription = briefDescription
        self.photoFilename = photoFilename
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
