import Foundation
import SwiftData
import HealthKit

@Observable
final class SleepManager {
    private(set) var activeSession: SleepSession?
    private(set) var detectedGaps: [DetectedGap] = []
    private(set) var isLoading = false

    private var modelContext: ModelContext?
    private var rescueTimeService: RescueTimeService?

    private let userDefaults = UserDefaults(suiteName: AppConstants.appGroupID)

    func configure(modelContext: ModelContext, rescueTimeService: RescueTimeService) {
        self.modelContext = modelContext
        self.rescueTimeService = rescueTimeService
        restoreActiveSession()
    }

    // MARK: - Session Lifecycle

    func startSleepSession() {
        let session = SleepSession()
        modelContext?.insert(session)
        try? modelContext?.save()

        activeSession = session
        userDefaults?.set(session.startTime.timeIntervalSince1970, forKey: AppConstants.UserDefaultsKey.sleepStartTimestamp)
    }

    func endSleepSession() async -> SleepSession? {
        guard let session = activeSession else { return nil }

        let ended = session.ended()
        modelContext?.insert(ended)
        try? modelContext?.save()

        activeSession = nil
        userDefaults?.removeObject(forKey: AppConstants.UserDefaultsKey.sleepStartTimestamp)

        await validateAndScore(session: ended)

        return ended
    }

    func confirmSleepSession(start: Date, end: Date, source: SleepSource = .manual) async {
        let session = SleepSession(startTime: start, source: source)
        let ended = session.ended(at: end)
        modelContext?.insert(ended)
        try? modelContext?.save()

        await validateAndScore(session: ended)
    }

    // MARK: - Auto-Detect

    func checkForSleepGaps() async {
        guard let service = rescueTimeService else { return }

        isLoading = true
        defer { isLoading = false }

        do {
            let yesterday = DateBoundary.yesterday()
            let gaps = try await service.findActivityGaps(date: yesterday)
            detectedGaps = gaps
        } catch {
            detectedGaps = []
        }
    }

    func dismissGap(_ gap: DetectedGap) {
        detectedGaps.removeAll { $0.start == gap.start && $0.end == gap.end }
    }

    // MARK: - Validation

    private func validateAndScore(session: SleepSession) async {
        guard let hours = session.durationHours else { return }

        var screenMinutes = 0
        var validationNote: String?

        if let service = rescueTimeService, let endTime = session.endTime {
            do {
                let validation = try await service.validateSleepWindow(
                    start: session.startTime,
                    end: endTime
                )
                screenMinutes = validation.screenMinutes
                validationNote = validation.note
            } catch {
                // Proceed without validation if RescueTime unavailable
            }
        }

        let rawScore = ScoreCalculator.sleepScore(
            hours: hours,
            goalHours: AppConstants.defaultSleepGoalHours
        )

        let (adjustedScore, scoreNote) = ScoreCalculator.validateSleep(
            rawScore: rawScore,
            screenMinutes: screenMinutes
        )

        let wakeTime = session.endTime ?? session.startTime
        let date = DateBoundary.logicalDate(for: wakeTime)
        let dateStr = DateBoundary.dateString(from: date)

        let descriptor = FetchDescriptor<DailySummary>(predicate: #Predicate { $0.dateString == dateStr })
        let existing = try? modelContext?.fetch(descriptor).first

        let summary = existing ?? DailySummary(date: date)
        if existing == nil {
            modelContext?.insert(summary)
        }

        summary.sleepStart = session.startTime
        summary.sleepEnd = session.endTime
        summary.sleepHours = hours
        summary.sleepScore = adjustedScore
        summary.sleepScreenMinutes = screenMinutes
        summary.sleepSource = session.source

        try? modelContext?.save()

        _ = validationNote ?? scoreNote
    }

    // MARK: - HealthKit Supplement

    func fetchHealthKitSleep() async -> (hours: Double, stages: [HKCategorySample])? {
        let store = HKHealthStore()
        guard HKHealthStore.isHealthDataAvailable() else { return nil }

        let sleepType = HKCategoryType(.sleepAnalysis)
        let status = store.authorizationStatus(for: sleepType)
        guard status == .sharingAuthorized else { return nil }

        let logicalToday = DateBoundary.today()
        let startDate = DateBoundary.dayStart(for: logicalToday)
        let endDate = DateBoundary.dayEnd(for: logicalToday)

        let predicate = HKQuery.predicateForSamples(
            withStart: startDate,
            end: endDate,
            options: .strictStartDate
        )

        return await withCheckedContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: sleepType,
                predicate: predicate,
                limit: HKObjectQueryNoLimit,
                sortDescriptors: [NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: true)]
            ) { _, samples, _ in
                guard let samples = samples as? [HKCategorySample] else {
                    continuation.resume(returning: nil)
                    return
                }

                let totalSeconds = samples.reduce(0.0) { total, sample in
                    total + sample.endDate.timeIntervalSince(sample.startDate)
                }
                let hours = totalSeconds / 3600.0

                continuation.resume(returning: (hours, samples))
            }

            store.execute(query)
        }
    }

    // MARK: - State Restoration

    private func restoreActiveSession() {
        guard let timestamp = userDefaults?.double(forKey: AppConstants.UserDefaultsKey.sleepStartTimestamp),
              timestamp > 0 else { return }

        let startTime = Date(timeIntervalSince1970: timestamp)
        let descriptor = FetchDescriptor<SleepSession>(predicate: #Predicate { $0.isActive == true })
        if let existing = try? modelContext?.fetch(descriptor).first {
            activeSession = existing
        } else {
            let session = SleepSession(startTime: startTime)
            modelContext?.insert(session)
            try? modelContext?.save()
            activeSession = session
        }
    }
}
