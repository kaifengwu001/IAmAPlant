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

    private let userDefaults = UserDefaults(suiteName: AppConstants.appGroupID)
    private var timerTask: Task<Void, Never>?
    private var modelContext: ModelContext?

    private static let totalSeconds = AppConstants.pomodoroWorkMinutes * 60

    // MARK: - Computed Properties (for debug view)

    var currentDistractionLevel: Int {
        SharedPomodoroStorage.loadDistractionLevel()
    }

    var extensionLog: [String] {
        SharedPomodoroStorage.loadExtensionLog()
    }

    var distractionSource: String {
        isFamilyControlsAvailable ? "ScreenTime" : "Unavailable"
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
        appendDebug("Restored session \(sessionID.uuidString.prefix(8)), \(remaining)s left")

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

        let distractedSeconds = distractedSecondsFromLevel()
        session.markInterrupted(distractedSeconds: distractedSeconds)
        try? modelContext?.save()
        refreshProductivitySummary(for: session.date)

        appendDebug("Cancelled: \(distractedSeconds)s distracted, \(session.durationMinutes)m")
        cleanup()
    }

    func onAppReturnFromBackground() async {
        backgroundHandlerConnected = true
        guard isRunning, let session = activeSession else { return }

        let elapsed = Int(Date.now.timeIntervalSince(session.startTime))
        let recalculated = max(0, Self.totalSeconds - elapsed)
        appendDebug("Foreground: elapsed \(elapsed)s, remaining \(recalculated)s (was \(remainingSeconds)s)")
        remainingSeconds = recalculated

        let level = SharedPomodoroStorage.loadDistractionLevel()
        appendDebug("Distraction level: \(level)")

        if level >= 3 {
            appendDebug("FAIL detected on foreground return")
            await failSession()
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
        appendDebug("Background: remaining \(remainingSeconds)s")
    }

    // MARK: - Timer

    private func startTimer() {
        timerTask?.cancel()
        timerTask = Task { @MainActor in
            var ticksSinceLastPoll = 0

            while remainingSeconds > 0 && !Task.isCancelled {
                try? await Task.sleep(for: .seconds(1))
                remainingSeconds -= 1
                ticksSinceLastPoll += 1

                if ticksSinceLastPoll >= 5 {
                    ticksSinceLastPoll = 0
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

    // MARK: - Session Completion

    private func completeSession() async {
        guard let session = activeSession else { return }

        if isFamilyControlsAvailable {
            stopDeviceActivityMonitoring(sessionID: session.sessionID)
        }

        let distractedSeconds = distractedSecondsFromLevel()
        session.markCompleted(distractedSeconds: distractedSeconds)
        try? modelContext?.save()
        refreshProductivitySummary(for: session.date)

        appendDebug("Completed: \(distractedSeconds)s distracted, \(session.durationMinutes)m")
        cleanup()
    }

    private func failSession() async {
        guard let session = activeSession else { return }

        if isFamilyControlsAvailable {
            stopDeviceActivityMonitoring(sessionID: session.sessionID)
        }

        session.markInterrupted(distractedSeconds: 180)
        try? modelContext?.save()
        refreshProductivitySummary(for: session.date)

        appendDebug("FAILED: 180s distracted, \(session.durationMinutes)m (3 min limit)")
        cleanup()
    }

    private func distractedSecondsFromLevel() -> Int {
        switch SharedPomodoroStorage.loadDistractionLevel() {
        case 3: return 180
        case 2: return 150
        case 1: return 60
        default: return 0
        }
    }

    private func refreshProductivitySummary(for date: Date) {
        guard let modelContext else { return }

        do {
            _ = try DailySummary.refreshProductivity(for: date, in: modelContext)
            try modelContext.save()
        } catch {
            appendDebug("Summary refresh failed: \(error.localizedDescription)")
        }
    }

    private func cleanup() {
        timerTask?.cancel()
        timerTask = nil
        activeSession = nil
        isRunning = false
        remainingSeconds = 0
        clearPersistedSessionID()
        SharedPomodoroStorage.clearSessionData()
    }

    // MARK: - DeviceActivity Monitoring

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
        let now = Date.now
        let sessionDuration = TimeInterval(Self.totalSeconds)
        let endDate = now.addingTimeInterval(sessionDuration + 60)

        let start = calendar.dateComponents([.hour, .minute, .second], from: now)
        let end = calendar.dateComponents([.hour, .minute, .second], from: endDate)

        let schedule = DeviceActivitySchedule(
            intervalStart: DateComponents(hour: start.hour, minute: start.minute, second: start.second),
            intervalEnd: DateComponents(hour: end.hour, minute: end.minute, second: end.second),
            repeats: false
        )

        let selection = DistractionPickerView.loadSelection()
        let appTokens = selection?.applicationTokens ?? []
        let catTokens = selection?.categoryTokens ?? []
        let webTokens = selection?.webDomainTokens ?? []

        let warn1Name = DeviceActivityEvent.Name(rawValue: "warn1_\(sessionID.uuidString)")
        let warn2Name = DeviceActivityEvent.Name(rawValue: "warn2_\(sessionID.uuidString)")
        let failName = DeviceActivityEvent.Name(rawValue: "fail_\(sessionID.uuidString)")

        let warn1 = DeviceActivityEvent(
            applications: appTokens,
            categories: catTokens,
            webDomains: webTokens,
            threshold: DateComponents(minute: 1)
        )
        let warn2 = DeviceActivityEvent(
            applications: appTokens,
            categories: catTokens,
            webDomains: webTokens,
            threshold: DateComponents(minute: 2, second: 30)
        )
        let fail = DeviceActivityEvent(
            applications: appTokens,
            categories: catTokens,
            webDomains: webTokens,
            threshold: DateComponents(minute: 3)
        )

        let events: [DeviceActivityEvent.Name: DeviceActivityEvent] = [
            warn1Name: warn1,
            warn2Name: warn2,
            failName: fail,
        ]

        let hasFilter = !appTokens.isEmpty || !catTokens.isEmpty || !webTokens.isEmpty
        appendDebug("DA schedule: \(start.hour ?? 0):\(start.minute ?? 0):\(start.second ?? 0) → \(end.hour ?? 0):\(end.minute ?? 0):\(end.second ?? 0)")
        appendDebug("DA events: 3 thresholds (1m, 2:30, 3m), filter=\(hasFilter ? "apps" : "all")")

        do {
            try center.startMonitoring(activityName, during: schedule, events: events)
            appendDebug("DA monitoring started OK, active=\(center.activities.count)")
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
