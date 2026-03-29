import Foundation

/// Detects phone usage during Pomodoro sessions by comparing ContinuousClock (ticks during sleep)
/// vs SuspendingClock (pauses during device sleep). Only used as fallback when FamilyControls unavailable.
actor ClockDriftService {
    private let userDefaults = UserDefaults(suiteName: AppConstants.appGroupID)

    struct BackgroundGap {
        let wallDuration: TimeInterval
        let continuousDuration: TimeInterval
        let suspendingDuration: TimeInterval
        let awakeRatio: Double
        let phoneWasUsed: Bool
    }

    /// Records clock values when the app enters background during an active Pomodoro.
    func recordBackgroundEntry() {
        let wallTime = Date.now.timeIntervalSince1970
        let continuousNanos = clock_gettime_nsec_np(CLOCK_MONOTONIC_RAW)
        let absoluteNanos = mach_absolute_time()

        userDefaults?.set(wallTime, forKey: AppConstants.UserDefaultsKey.pomodoroBackgroundEntryWall)
        userDefaults?.set(Double(continuousNanos), forKey: AppConstants.UserDefaultsKey.pomodoroBackgroundEntryContinuous)
        userDefaults?.set(Double(absoluteNanos), forKey: AppConstants.UserDefaultsKey.pomodoroBackgroundEntryAbsolute)
    }

    /// Computes the awake ratio for the gap between background entry and now.
    /// awakeRatio near 1.0 = phone was active (user was on it).
    /// awakeRatio near 0 = phone was sleeping (user was not on it).
    func analyzeBackgroundGap() -> BackgroundGap? {
        guard let entryWall = userDefaults?.double(forKey: AppConstants.UserDefaultsKey.pomodoroBackgroundEntryWall),
              entryWall > 0,
              let entryContinuous = userDefaults?.double(forKey: AppConstants.UserDefaultsKey.pomodoroBackgroundEntryContinuous),
              let entryAbsolute = userDefaults?.double(forKey: AppConstants.UserDefaultsKey.pomodoroBackgroundEntryAbsolute) else {
            return nil
        }

        let nowWall = Date.now.timeIntervalSince1970
        let nowContinuous = Double(clock_gettime_nsec_np(CLOCK_MONOTONIC_RAW))
        let nowAbsolute = Double(mach_absolute_time())

        let wallDuration = nowWall - entryWall
        guard wallDuration > 1 else { return nil }

        let continuousDuration = (nowContinuous - entryContinuous) / 1_000_000_000.0
        let absoluteDuration = (nowAbsolute - entryAbsolute) / 1_000_000_000.0

        // ContinuousClock ticks even during device sleep; SuspendingClock doesn't.
        // mach_absolute_time approximates SuspendingClock behavior.
        // If awake ratio is high, the phone was being used during the gap.
        let awakeRatio = wallDuration > 0 ? min(absoluteDuration / wallDuration, 1.0) : 0

        clearBackgroundEntry()

        return BackgroundGap(
            wallDuration: wallDuration,
            continuousDuration: continuousDuration,
            suspendingDuration: absoluteDuration,
            awakeRatio: awakeRatio,
            phoneWasUsed: awakeRatio > 0.5
        )
    }

    func clearBackgroundEntry() {
        userDefaults?.removeObject(forKey: AppConstants.UserDefaultsKey.pomodoroBackgroundEntryWall)
        userDefaults?.removeObject(forKey: AppConstants.UserDefaultsKey.pomodoroBackgroundEntryContinuous)
        userDefaults?.removeObject(forKey: AppConstants.UserDefaultsKey.pomodoroBackgroundEntryAbsolute)
    }
}
