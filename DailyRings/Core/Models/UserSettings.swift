import Foundation
import SwiftData

@Model
final class UserSettings {
    var userID: String
    var sleepGoalHours: Double
    var exerciseGoalMinutes: Int
    var productivityGoalMinutes: Int
    var rescueTimeAPIKey: String?
    var dayBoundaryHour: Int
    var mealPhotoRetentionDays: Int
    var createdAt: Date
    var updatedAt: Date

    init(userID: String = "local") {
        self.userID = userID
        self.sleepGoalHours = AppConstants.defaultSleepGoalHours
        self.exerciseGoalMinutes = AppConstants.defaultExerciseGoalMinutes
        self.productivityGoalMinutes = AppConstants.defaultProductivityGoalMinutes
        self.dayBoundaryHour = AppConstants.defaultDayBoundaryHour
        self.mealPhotoRetentionDays = 7
        self.createdAt = .now
        self.updatedAt = .now
    }

    func withUpdated<V>(keyPath: WritableKeyPath<UserSettings, V>, value: V) -> UserSettings {
        var copy = UserSettings(userID: userID)
        copy.sleepGoalHours = sleepGoalHours
        copy.exerciseGoalMinutes = exerciseGoalMinutes
        copy.productivityGoalMinutes = productivityGoalMinutes
        copy.rescueTimeAPIKey = rescueTimeAPIKey
        copy.dayBoundaryHour = dayBoundaryHour
        copy.mealPhotoRetentionDays = mealPhotoRetentionDays
        copy.createdAt = createdAt
        copy.updatedAt = .now
        copy[keyPath: keyPath] = value
        return copy
    }
}
