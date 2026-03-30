import Foundation
import SwiftData
import FamilyControls
import DeviceActivity
import ManagedSettings
import UserNotifications

@Observable
final class PomodoroManager {
    private(set) var activeSession: PomodoroSession?
    private(set) var isRunning = false
    private(set) var remainingSeconds: Int = 0
    private(set) var isFamilyControlsAvailable = false
    private(set) var backgroundHandlerConnected = false
    private(set) var debugLog: [String] = []

    private let clockDriftService = ClockDriftService()
    private let backgroundStateService = BackgroundStateService()
    private let userDefaults = UserDefaults(suiteName: AppConstants.appGroupID)
    private var timerTask: Task<Void, Never>?
    private var modelContext: ModelContext?

    private var foregroundEntryTime: Date?
    private var accumulatedForegroundSeconds: Int = 0

    private static let totalSeconds = AppConstants.pomodoroWorkMinutes * 60

    // MARK: - Computed Properties (for debug view)

    var currentForegroundSeconds: Int {
        var total = accumulatedForegroundSeconds
        if let entry = foregroundEntryTime {
            total += Int(Date.now.timeIntervalSince(entry))
        }
        return total
    }

    var currentDistractionLevel: Int {
        SharedPomodoroStorage.loadDistractionLevel()
    }

    var distractionEventsThisSession: [PomodoroEvent] {
        guard let session = activeSession else { return [] }
        return SharedPomodoroStorage.loadEvents()
            .filter { $0.sessionID == session.sessionID && $0.eventType == .screenTimeThreshold }
    }

    var allEventsThisSession: [PomodoroEvent] {
        guard let session = activeSession else { return [] }
        return SharedPomodoroStorage.loadEvents()
            .filter { $0.sessionID == session.sessionID }
    }

    var extensionLog: [String] {
        SharedPomodoroStorage.loadExtensionLog()
    }

    var distractionSource: String {
        isFamilyControlsAvailable ? "FamilyControls + Clock Drift" : "Clock Drift Only"
    }

    // MARK: - Configuration

    func configure(modelContext: ModelContext) {
        self.modelContext = modelContext
        checkFamilyControlsAvailability()
        restoreActiveSessionIfNeeded()
    }

    private func restoreActiveSessionIfNeeded() {
        guard let idString = userDefaults?.string(forKey: AppConstants.UserDefaultsKey.activePomodoroSessionID),
              let sessionID = UUID(uuidString: idString),
              let ctx = modelContext else { return }

        let descriptor = FetchDescriptor<PomodoroSession>(
            predicate: #Predicate { $0.sessionID == sessionID && $0.endTime == nil }
        )
        guard let session = try? ctx.fetch(descriptor).first else {
            clearPersistedSessionID()
            return
        }

        let elapsed = Int(Date.now.timeIntervalSince(session.startTime))
        let remaining = max(0, Self.totalSeconds - elapsed)

        activeSession = session
        isRunning = true
        remainingSeconds = remaining
        foregroundEntryTime = .now
        accumulatedForegroundSeconds = SharedPomodoroStorage.loadForegroundSeconds()
        appendDebug("Restored session \(sessionID.uuidString.prefix(8)), \(remaining)s left, fg=\(accumulatedForegroundSeconds)s")

        if remaining <= 0 {
            Task { await completeSession() }
        } else {
            startTimer()
        }
    }

    private func persistSessionID(_ id: UUID) {
        userDefaults?.set(id.uuidString, forKey: AppConstants.UserDefaultsKey.activePomodoroSessionID)
    }

    private func clearPersistedSessionID() {
        userDefaults?.removeObject(forKey: AppConstants.UserDefaultsKey.activePomodoroSessionID)
    }

    private func appendDebug(_ message: String) {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        let entry = "[\(formatter.string(from: .now))] \(message)"
        debugLog.append(entry)
        if debugLog.count > 50 { debugLog.removeFirst() }
    }

    // MARK: - Session Lifecycle

    func startSession(label: String, category: String) async {
        let date = DateBoundary.today()
        let session = PomodoroSession(goalLabel: label, category: category, date: date)

        modelContext?.insert(session)
        try? modelContext?.save()

        activeSession = session
        isRunning = true
        remainingSeconds = Self.totalSeconds
        foregroundEntryTime = .now
        accumulatedForegroundSeconds = 0
        SharedPomodoroStorage.saveForegroundSeconds(0)
        SharedPomodoroStorage.saveDistractionLevel(0)
        persistSessionID(session.sessionID)

        if isFamilyControlsAvailable {
            await startDeviceActivityMonitoring(sessionID: session.sessionID)
        }

        appendDebug("Started session, source: \(distractionSource)")
        await scheduleCompletionNotification()
        startTimer()
    }

    func cancelSession() async {
        guard let session = activeSession else { return }

        if isFamilyControlsAvailable {
            stopDeviceActivityMonitoring(sessionID: session.sessionID)
        }

        let distractedSeconds = computeDistractedSeconds(for: session.sessionID)
        session.markInterrupted(distractedSeconds: distractedSeconds)
        try? modelContext?.save()

        appendDebug("Cancelled: \(distractedSeconds)s distracted, \(session.durationMinutes)m")
        cleanup()
    }

    func onAppReturnFromBackground() async {
        backgroundHandlerConnected = true
        guard isRunning, let session = activeSession else { return }

        foregroundEntryTime = .now

        let elapsed = Int(Date.now.timeIntervalSince(session.startTime))
        let recalculated = max(0, Self.totalSeconds - elapsed)
        appendDebug("Foreground: elapsed \(elapsed)s, remaining \(recalculated)s (was \(remainingSeconds)s)")
        remainingSeconds = recalculated

        if let gap = await clockDriftService.analyzeBackgroundGap() {
            appendDebug("Clock drift: wall=\(String(format: "%.1f", gap.wallDuration))s, awake=\(String(format: "%.2f", gap.awakeRatio)), used=\(gap.phoneWasUsed)")
            if gap.phoneWasUsed {
                let durationSecs = Int(gap.wallDuration)
                SharedPomodoroStorage.saveEvent(PomodoroEvent(
                    sessionID: session.sessionID,
                    timestamp: .now,
                    eventType: .distractionDetected,
                    durationSeconds: durationSecs
                ))
            }
        } else {
            appendDebug("Clock drift: no background entry recorded")
        }

        let level = SharedPomodoroStorage.loadDistractionLevel()
        appendDebug("Distraction level: \(level), fg=\(currentForegroundSeconds)s")

        if level >= 3 {
            appendDebug("FAIL detected on foreground return")
            await failSession()
            return
        }

        if sessionEvents(for: session.sessionID).contains(where: { $0.eventType == .completed }) {
            await completeSession()
            return
        }

        if recalculated <= 0 {
            await completeSession()
            return
        }

        timerTask?.cancel()
        startTimer()
    }

    func onAppEnterBackground() async {
        backgroundHandlerConnected = true
        guard isRunning else { return }

        if let entry = foregroundEntryTime {
            accumulatedForegroundSeconds += Int(Date.now.timeIntervalSince(entry))
            foregroundEntryTime = nil
            SharedPomodoroStorage.saveForegroundSeconds(accumulatedForegroundSeconds)
        }

        appendDebug("Background: remaining \(remainingSeconds)s, fg=\(accumulatedForegroundSeconds)s")
        await clockDriftService.recordBackgroundEntry()
        await backgroundStateService.checkLockStateDuringPomodoro()
    }

    // MARK: - Timer

    private func startTimer() {
        timerTask?.cancel()
        timerTask = Task { @MainActor in
            var ticksSinceLastSync = 0

            while remainingSeconds > 0 && !Task.isCancelled {
                try? await Task.sleep(for: .seconds(1))
                remainingSeconds -= 1
                ticksSinceLastSync += 1

                if ticksSinceLastSync >= 5 {
                    ticksSinceLastSync = 0
                    syncForegroundTime()

                    let level = SharedPomodoroStorage.loadDistractionLevel()
                    if level >= 3 {
                        appendDebug("Poll: FAIL (level=3)")
                        await failSession()
                        return
                    }
                }
            }

            if remainingSeconds <= 0 && !Task.isCancelled {
                await completeSession()
            }
        }
    }

    private func syncForegroundTime() {
        guard foregroundEntryTime != nil else { return }
        let total = currentForegroundSeconds
        SharedPomodoroStorage.saveForegroundSeconds(total)
    }

    // MARK: - Session Completion

    private func completeSession() async {
        guard let session = activeSession else { return }

        if isFamilyControlsAvailable {
            stopDeviceActivityMonitoring(sessionID: session.sessionID)
        }

        let distractedSeconds = computeDistractedSeconds(for: session.sessionID)
        session.markCompleted(distractedSeconds: distractedSeconds)
        try? modelContext?.save()

        appendDebug("Completed: \(distractedSeconds)s distracted, \(session.durationMinutes)m")
        cleanup()
    }

    private func failSession() async {
        guard let session = activeSession else { return }

        if isFamilyControlsAvailable {
            stopDeviceActivityMonitoring(sessionID: session.sessionID)
        }

        let distractedSeconds = computeDistractedSeconds(for: session.sessionID)
        session.markInterrupted(distractedSeconds: distractedSeconds)
        try? modelContext?.save()

        appendDebug("FAILED: \(distractedSeconds)s distracted, \(session.durationMinutes)m (3 min limit)")
        cleanup()
    }

    private func computeDistractedSeconds(for sessionID: UUID) -> Int {
        let events = sessionEvents(for: sessionID)
        let fg = currentForegroundSeconds
        let baseline = SharedPomodoroStorage.loadScreenTimeBaseline()

        let highestThreshold = events
            .filter { $0.eventType == .screenTimeThreshold }
            .map(\.durationSeconds)
            .max() ?? 0
        let newScreenTime = max(0, highestThreshold - baseline)
        let adjustedFromThreshold = max(0, newScreenTime - fg)

        let clockDriftSeconds = events
            .filter { $0.eventType == .distractionDetected }
            .reduce(0) { $0 + $1.durationSeconds }

        return max(adjustedFromThreshold, clockDriftSeconds)
    }

    private func sessionEvents(for sessionID: UUID) -> [PomodoroEvent] {
        SharedPomodoroStorage.loadEvents().filter { $0.sessionID == sessionID }
    }

    private func cleanup() {
        timerTask?.cancel()
        timerTask = nil
        activeSession = nil
        isRunning = false
        remainingSeconds = 0
        foregroundEntryTime = nil
        accumulatedForegroundSeconds = 0
        clearPersistedSessionID()
        SharedPomodoroStorage.clearSessionData()
    }

    // MARK: - DeviceActivity

    private func checkFamilyControlsAvailability() {
        Task {
            do {
                try await AuthorizationCenter.shared.requestAuthorization(for: .individual)
                isFamilyControlsAvailable = true
            } catch {
                isFamilyControlsAvailable = false
            }
        }
    }

    private func startDeviceActivityMonitoring(sessionID: UUID) async {
        let center = DeviceActivityCenter()
        let activityName = DeviceActivityName(rawValue: sessionID.uuidString)

        let calendar = Calendar.current
        let startDate = Date.now.addingTimeInterval(10)
        let sessionDuration = TimeInterval(Self.totalSeconds)
        let endDate = Date.now.addingTimeInterval(sessionDuration + 60)

        let start = calendar.dateComponents([.hour, .minute, .second], from: startDate)
        let end = calendar.dateComponents([.hour, .minute, .second], from: endDate)

        let schedule = DeviceActivitySchedule(
            intervalStart: DateComponents(hour: start.hour, minute: start.minute, second: start.second),
            intervalEnd: DateComponents(hour: end.hour, minute: end.minute, second: end.second),
            repeats: false
        )

        var events: [DeviceActivityEvent.Name: DeviceActivityEvent] = [:]
        let thresholds = Self.buildThresholdSeconds()
        for s in thresholds {
            let name = DeviceActivityEvent.Name(rawValue: "t\(s)_\(sessionID.uuidString)")
            let threshold = DateComponents(hour: s / 3600, minute: (s % 3600) / 60, second: s % 60)
            events[name] = DeviceActivityEvent(threshold: threshold)
        }

        appendDebug("DA schedule: \(start.hour ?? 0):\(start.minute ?? 0):\(start.second ?? 0) → \(end.hour ?? 0):\(end.minute ?? 0):\(end.second ?? 0)")
        appendDebug("DA events: \(events.count) thresholds (up to \(thresholds.last ?? 0)s)")

        do {
            try center.startMonitoring(activityName, during: schedule, events: events)
            appendDebug("DA monitoring started OK")
            appendDebug("DA active monitors: \(center.activities.count)")
        } catch {
            appendDebug("DA monitoring FAILED: \(error.localizedDescription)")
            isFamilyControlsAvailable = false
        }
    }

    private func stopDeviceActivityMonitoring(sessionID: UUID) {
        let center = DeviceActivityCenter()
        let activityName = DeviceActivityName(rawValue: sessionID.uuidString)
        center.stopMonitoring([activityName])
    }

    // MARK: - Notifications

    private func scheduleCompletionNotification() async {
        let content = UNMutableNotificationContent()
        content.title = "Pomodoro Complete"
        content.body = "Great work! Take a 5-minute break."
        content.sound = .default

        let trigger = UNTimeIntervalNotificationTrigger(
            timeInterval: TimeInterval(AppConstants.pomodoroWorkMinutes * 60),
            repeats: false
        )

        let request = UNNotificationRequest(
            identifier: "pomodoro-complete",
            content: content,
            trigger: trigger
        )

        try? await UNUserNotificationCenter.current().add(request)
    }

    // MARK: - Formatting

    var formattedTime: String {
        let minutes = remainingSeconds / 60
        let seconds = remainingSeconds % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
}
