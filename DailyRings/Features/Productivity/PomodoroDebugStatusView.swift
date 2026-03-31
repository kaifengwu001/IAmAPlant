import SwiftUI
import SwiftData

struct PomodoroDebugStatusView: View {
    @Environment(PomodoroManager.self) private var manager
    @Query private var settings: [UserSettings]

    private var rescueTimeConnected: Bool {
        guard let key = settings.first?.rescueTimeAPIKey else { return false }
        return !key.isEmpty
    }

    private var startTimeLabel: String {
        guard let start = manager.activeSession?.startTime else { return "--" }
        return Self.timeFmt.string(from: start)
    }

    private static let timeFmt: DateFormatter = {
        let fmt = DateFormatter()
        fmt.dateFormat = "h:mm:ss a"
        return fmt
    }()

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            sectionHeader("STATUS")

            row(
                status: manager.isFamilyControlsAvailable ? .good : .bad,
                label: "ScreenTime",
                value: manager.isFamilyControlsAvailable ? "Auth" : "No"
            )

            row(
                status: rescueTimeConnected ? .good : .bad,
                label: "RescueTime",
                value: rescueTimeConnected ? "Key set" : "No"
            )

            row(
                status: manager.backgroundHandlerConnected ? .good : .bad,
                label: "scenePhase",
                value: manager.backgroundHandlerConnected ? "Wired" : "Pending"
            )

            row(
                status: .good,
                label: "Source",
                value: manager.distractionSource
            )

            row(
                status: DistractionPickerView.hasSelection ? .good : .warning,
                label: "App filter",
                value: DistractionPickerView.hasSelection ? "Configured" : "All apps"
            )

            if manager.isRunning {
                timerSection
                distractionSection
            }

            extensionLogSection
            appLogSection
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(Theme.surfacePrimary)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .padding(.horizontal, 12)
    }

    // MARK: - Timer

    private var timerSection: some View {
        Group {
            sectionHeader("TIMER")
            row(status: .good, label: "Start time", value: startTimeLabel)
            row(status: .good, label: "Remaining", value: "\(manager.remainingSeconds)s (\(manager.formattedTime))")
        }
    }

    // MARK: - Distraction

    private var distractionSection: some View {
        Group {
            let level = manager.currentDistractionLevel
            let levelLabels = ["None", "Warning (1m)", "Critical (2:30)", "FAIL (3m)"]

            sectionHeader("DISTRACTION")

            row(
                status: level >= 3 ? .bad : (level >= 1 ? .warning : .good),
                label: "Level",
                value: levelLabels[min(level, 3)]
            )
        }
    }

    // MARK: - Extension Log

    private var extensionLogSection: some View {
        Group {
            sectionHeader("EXTENSION LOG (\(manager.extensionLog.count))")

            if manager.extensionLog.isEmpty {
                monoText("No extension callbacks received")
            } else {
                ForEach(Array(manager.extensionLog.suffix(10).enumerated()), id: \.offset) { _, entry in
                    monoText(entry)
                }
            }
        }
    }

    // MARK: - App Log

    private var appLogSection: some View {
        Group {
            sectionHeader("APP LOG (\(manager.debugLog.count))")

            if manager.debugLog.isEmpty {
                monoText("No app log entries")
            } else {
                ForEach(Array(manager.debugLog.suffix(12).enumerated()), id: \.offset) { _, entry in
                    monoText(entry)
                }
            }
        }
    }

    // MARK: - Components

    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(.system(.caption2, design: .monospaced, weight: .bold))
            .foregroundStyle(Theme.textQuaternary)
            .padding(.top, 6)
    }

    private func monoText(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 9, design: .monospaced))
            .foregroundStyle(Theme.textTertiary)
            .fixedSize(horizontal: false, vertical: true)
    }

    private enum StatusLevel {
        case good, warning, bad

        var color: Color {
            switch self {
            case .good: Theme.accent
            case .warning: Theme.accent
            case .bad: Theme.exercise
            }
        }
    }

    private func row(status: StatusLevel, label: String, value: String) -> some View {
        HStack(alignment: .top, spacing: 6) {
            Circle()
                .fill(status.color)
                .frame(width: 6, height: 6)
                .padding(.top, 3)

            Text(label)
                .font(.system(size: 9, design: .monospaced))
                .foregroundStyle(Theme.textSecondary)
                .layoutPriority(1)

            Spacer(minLength: 4)

            Text(value)
                .font(.system(size: 9, weight: .medium, design: .monospaced))
                .foregroundStyle(Theme.textSecondary)
                .multilineTextAlignment(.trailing)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}
