import Foundation

enum AppConstants {
    static let appGroupID = "group.com.kai.dailyrings"
    static let suiteName = appGroupID

    static let defaultSleepGoalHours: Double = 8.0
    static let defaultExerciseGoalMinutes: Int = 30
    static let defaultProductivityGoalMinutes: Int = 480
    static let defaultDayBoundaryHour: Int = 4

    static let pomodoroWorkMinutes: Int = 25
    static let pomodoroBreakMinutes: Int = 5

    static let mealPhotoMaxAge: TimeInterval = 7 * 24 * 60 * 60
    static let mealPhotoMaxDimension: CGFloat = 800

    static let rescueTimeMinActivityGapHours: Double = 3.0
    static let sleepScreenTimeThresholdMinor: Int = 10
    static let sleepScreenTimeThresholdMajor: Int = 30

    enum UserDefaultsKey {
        static let sleepStartTimestamp = "sleepStartTimestamp"
        static let activePomodoroSessionID = "activePomodoroSessionID"
        static let pomodoroBackgroundEntryWall = "pomodoroBackgroundEntryWall"
        static let pomodoroBackgroundEntryContinuous = "pomodoroBackgroundEntryContinuous"
        static let pomodoroBackgroundEntryAbsolute = "pomodoroBackgroundEntryAbsolute"
    }

    enum Ring: Int, CaseIterable {
        case sleep = 0
        case exercise = 1
        case nutrition = 2
        case productivity = 3

        var scoreIndex: Int { rawValue }

        static let displayOrderInnerToOuter: [Ring] = [
            .sleep,
            .nutrition,
            .exercise,
            .productivity
        ]

        static let displayOrderOuterToInner: [Ring] = [
            .productivity,
            .exercise,
            .nutrition,
            .sleep
        ]

        var label: String {
            switch self {
            case .sleep: "Sleep"
            case .exercise: "Exercise"
            case .nutrition: "Nutrition"
            case .productivity: "Productivity"
            }
        }

        var iconName: String {
            switch self {
            case .sleep: "moon.fill"
            case .exercise: "figure.run"
            case .nutrition: "fork.knife"
            case .productivity: "brain.head.profile"
            }
        }

        var color: String {
            switch self {
            case .sleep: "ringSleep"
            case .exercise: "ringExercise"
            case .nutrition: "ringNutrition"
            case .productivity: "ringProductivity"
            }
        }
    }
}
