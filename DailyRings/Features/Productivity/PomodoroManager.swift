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

    private let clockDriftService = ClockDriftService()
    private let backgroundStateService = BackgroundStateService()
    private var timerTask: Task<Void, Never>?
    private var modelContext: ModelContext?

    func configure(modelContext: ModelContext) {
        self.modelContext = modelContext
        checkFamilyControlsAvailability()
    }

    // MARK: - Session Lifecycle

    func startSession(label: String, category: String) async {
        let date = DateBoundary.today()
        let session = PomodoroSession(goalLabel: label, category: category, date: date)

        modelContext?.insert(session)
        try? modelContext?.save()

        activeSession = session
        isRunning = true
        remainingSeconds = AppConstants.pomodoroWorkMinutes * 60

        if isFamilyControlsAvailable {
            await startDeviceActivityMonitoring(sessionID: session.sessionID)
        }

        await scheduleCompletionNotification()
        startTimer()
    }

    func cancelSession() async {
        guard let session = activeSession else { return }

        if isFamilyControlsAvailable {
            stopDeviceActivityMonitoring(sessionID: session.sessionID)
        }

        let events = SharedPomodoroStorage.loadEvents()
            .filter { $0.sessionID == session.sessionID }
        let distractedSeconds = events
            .filter { $0.eventType == .distractionDetected }
            .count * 60

        let interrupted = session.interrupted(distractedSeconds: distractedSeconds)
        modelContext?.insert(interrupted)
        try? modelContext?.save()

        cleanup()
        SharedPomodoroStorage.clearEvents()
    }

    func onAppReturnFromBackground() async {
        guard isRunning, activeSession != nil else { return }

        if !isFamilyControlsAvailable {
            if let gap = await clockDriftService.analyzeBackgroundGap() {
                if gap.phoneWasUsed {
                    let events = SharedPomodoroStorage.loadEvents()
                    SharedPomodoroStorage.saveEvent(PomodoroEvent(
                        sessionID: activeSession!.sessionID,
                        timestamp: .now,
                        eventType: .distractionDetected
                    ))
                    _ = events
                }
            }
        }

        let events = SharedPomodoroStorage.loadEvents()
            .filter { $0.sessionID == activeSession?.sessionID }

        if events.contains(where: { $0.eventType == .completed }) {
            await completeSession()
        }
    }

    func onAppEnterBackground() async {
        guard isRunning else { return }

        if !isFamilyControlsAvailable {
            await clockDriftService.recordBackgroundEntry()
        }
        await backgroundStateService.checkLockStateDuringPomodoro()
    }

    // MARK: - Timer

    private func startTimer() {
        timerTask?.cancel()
        timerTask = Task { @MainActor in
            while remainingSeconds > 0 && !Task.isCancelled {
                try? await Task.sleep(for: .seconds(1))
                remainingSeconds -= 1
            }

            if remainingSeconds <= 0 && !Task.isCancelled {
                await completeSession()
            }
        }
    }

    private func completeSession() async {
        guard let session = activeSession else { return }

        if isFamilyControlsAvailable {
            stopDeviceActivityMonitoring(sessionID: session.sessionID)
        }

        let events = SharedPomodoroStorage.loadEvents()
            .filter { $0.sessionID == session.sessionID }
        let distractedSeconds = events
            .filter { $0.eventType == .distractionDetected }
            .count * 60

        let completed = session.completed(distractedSeconds: distractedSeconds)
        modelContext?.insert(completed)
        try? modelContext?.save()

        cleanup()
        SharedPomodoroStorage.clearEvents()
    }

    private func cleanup() {
        timerTask?.cancel()
        timerTask = nil
        activeSession = nil
        isRunning = false
        remainingSeconds = 0
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

        let now = Calendar.current.dateComponents([.hour, .minute, .second], from: .now)
        let endDate = Date.now.addingTimeInterval(TimeInterval(AppConstants.pomodoroWorkMinutes * 60))
        let end = Calendar.current.dateComponents([.hour, .minute, .second], from: endDate)

        let schedule = DeviceActivitySchedule(
            intervalStart: DateComponents(hour: now.hour, minute: now.minute, second: now.second),
            intervalEnd: DateComponents(hour: end.hour, minute: end.minute, second: end.second),
            repeats: false
        )

        let eventName = DeviceActivityEvent.Name(rawValue: "distraction_\(sessionID.uuidString)")
        let event = DeviceActivityEvent(
            threshold: DateComponents(minute: 1)
        )

        do {
            try center.startMonitoring(
                activityName,
                during: schedule,
                events: [eventName: event]
            )
        } catch {
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
