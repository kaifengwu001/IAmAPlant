import Foundation

/// Detects phone usage during Pomodoro sessions by comparing ContinuousClock (ticks during sleep)
/// vs SuspendingClock (pauses during device sleep). Only used as fallback when FamilyControls unavailable.
///
/// mach_absolute_time() pauses during deep sleep; CLOCK_MONOTONIC_RAW keeps ticking.
/// awakeRatio = (suspending elapsed) / (wall elapsed):
///   near 1.0 → phone was awake the whole time (user distracted)
///   near 0.0 → phone was sleeping (user focused)
actor ClockDriftService {
    private let userDefaults = UserDefaults(suiteName: AppConstants.appGroupID)
    private let machTimebaseNanosPerTick: Double = {
        var info = mach_timebase_info_data_t()
        mach_timebase_info(&info)
        return Double(info.numer) / Double(info.denom)
    }()

    struct BackgroundGap {
        let wallDuration: TimeInterval
        let continuousDuration: TimeInterval
        let suspendingDuration: TimeInterval
        let awakeRatio: Double
        let phoneWasUsed: Bool
    }

    func recordBackgroundEntry() {
        let wallTime = Date.now.timeIntervalSince1970
        let continuousNanos = clock_gettime_nsec_np(CLOCK_MONOTONIC_RAW)
        let absoluteTicks = mach_absolute_time()

        userDefaults?.set(wallTime, forKey: AppConstants.UserDefaultsKey.pomodoroBackgroundEntryWall)
        userDefaults?.set(Double(continuousNanos), forKey: AppConstants.UserDefaultsKey.pomodoroBackgroundEntryContinuous)
        userDefaults?.set(Double(absoluteTicks), forKey: AppConstants.UserDefaultsKey.pomodoroBackgroundEntryAbsolute)
    }

    func analyzeBackgroundGap() -> BackgroundGap? {
        guard let entryWall = userDefaults?.double(forKey: AppConstants.UserDefaultsKey.pomodoroBackgroundEntryWall),
              entryWall > 0,
              let entryContinuousNanos = userDefaults?.double(forKey: AppConstants.UserDefaultsKey.pomodoroBackgroundEntryContinuous),
              let entryAbsoluteTicks = userDefaults?.double(forKey: AppConstants.UserDefaultsKey.pomodoroBackgroundEntryAbsolute) else {
            return nil
        }

        let nowWall = Date.now.timeIntervalSince1970
        let nowContinuousNanos = Double(clock_gettime_nsec_np(CLOCK_MONOTONIC_RAW))
        let nowAbsoluteTicks = Double(mach_absolute_time())

        let wallDuration = nowWall - entryWall
        guard wallDuration > 1 else { return nil }

        let continuousDuration = (nowContinuousNanos - entryContinuousNanos) / 1_000_000_000.0

        let absoluteTicksDelta = nowAbsoluteTicks - entryAbsoluteTicks
        let suspendingDuration = (absoluteTicksDelta * machTimebaseNanosPerTick) / 1_000_000_000.0

        let awakeRatio = wallDuration > 0 ? min(suspendingDuration / wallDuration, 1.0) : 0

        clearBackgroundEntry()

        return BackgroundGap(
            wallDuration: wallDuration,
            continuousDuration: continuousDuration,
            suspendingDuration: suspendingDuration,
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
