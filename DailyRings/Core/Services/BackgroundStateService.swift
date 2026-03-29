import UIKit

/// Checks device lock state during Pomodoro sessions using the background task API.
/// If the device is unlocked (user on another app), sends a gentle reminder notification.
final class BackgroundStateService: @unchecked Sendable {
    private var backgroundTaskID: UIBackgroundTaskIdentifier = .invalid

    @MainActor
    func checkLockStateDuringPomodoro() async {
        let taskID = UIApplication.shared.beginBackgroundTask {
            // Expiration handler — system is reclaiming time
        }
        guard taskID != .invalid else { return }

        try? await Task.sleep(for: .seconds(15))

        let isUnlocked = UIApplication.shared.isProtectedDataAvailable
        if isUnlocked {
            await sendFocusReminder()
        }

        UIApplication.shared.endBackgroundTask(taskID)
    }

    private func sendFocusReminder() async {
        let content = UNMutableNotificationContent()
        content.title = "Focus Session Active"
        content.body = "Your Pomodoro session is still running. Stay focused!"
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: "pomodoro-focus-reminder-\(UUID().uuidString)",
            content: content,
            trigger: nil
        )

        try? await UNUserNotificationCenter.current().add(request)
    }
}
