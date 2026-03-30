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

            if manager.isRunning {
                timerSection
                distractionSection
                sharedEventsSection
            }

            extensionLogSection
            appLogSection
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(Color.white.opacity(0.05))
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

    // MARK: - Distraction (the key section)

    private var distractionSection: some View {
        Group {
            let fg = manager.currentForegroundSeconds
            let level = manager.currentDistractionLevel
            let baseline = SharedPomodoroStorage.loadScreenTimeBaseline()
            let highestThreshold = manager.distractionEventsThisSession
                .map(\.durationSeconds).max() ?? 0
            let newScreenTime = max(0, highestThreshold - baseline)
            let adjusted = max(0, newScreenTime - fg)
            let levelLabel = ["None", "Warning (1m)", "Critical (2:30)", "FAIL (3m)"]

            sectionHeader("DISTRACTION")

            row(status: .good, label: "Baseline", value: "\(baseline)s (daily prior)")
            row(status: .good, label: "Our app fg", value: "\(fg)s")
            row(
                status: highestThreshold > 0 ? .warning : .good,
                label: "OS total",
                value: highestThreshold > 0 ? "≥\(highestThreshold)s" : "0s"
            )
            row(
                status: newScreenTime > 0 ? .warning : .good,
                label: "New screen time",
                value: "\(newScreenTime)s"
            )
            row(
                status: adjusted >= 60 ? (adjusted >= 150 ? .bad : .warning) : .good,
                label: "Adj distraction",
                value: "\(adjusted)s"
            )
            row(
                status: level >= 3 ? .bad : (level >= 1 ? .warning : .good),
                label: "Level",
                value: levelLabel[min(level, 3)]
            )
        }
    }

    // MARK: - Shared Events

    private var sharedEventsSection: some View {
        Group {
            sectionHeader("SHARED EVENTS (\(manager.allEventsThisSession.count))")

            if manager.allEventsThisSession.isEmpty {
                monoText("No events in SharedPomodoroStorage", opacity: 0.3)
            } else {
                ForEach(Array(manager.allEventsThisSession.suffix(8).enumerated()), id: \.offset) { _, event in
                    eventRow(event)
                }
            }
        }
    }

    private func eventRow(_ event: PomodoroEvent) -> some View {
        let typeIcon: String = {
            switch event.eventType {
            case .started: return "play.fill"
            case .completed: return "checkmark.circle.fill"
            case .screenTimeThreshold: return "clock.fill"
            case .distractionDetected: return "exclamationmark.triangle.fill"
            case .interrupted: return "xmark.circle.fill"
            }
        }()

        return HStack(spacing: 4) {
            Image(systemName: typeIcon)
                .font(.system(size: 7))
                .foregroundStyle(eventColor(event.eventType))
            Text(event.eventType.rawValue)
                .font(.system(size: 8, design: .monospaced))
                .foregroundStyle(.white.opacity(0.6))
                .lineLimit(1)
            Spacer(minLength: 2)
            if event.durationSeconds > 0 {
                Text("\(event.durationSeconds)s")
                    .font(.system(size: 8, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.5))
            }
            Text(Self.timeFmt.string(from: event.timestamp))
                .font(.system(size: 8, design: .monospaced))
                .foregroundStyle(.white.opacity(0.35))
        }
    }

    // MARK: - Extension Log

    private var extensionLogSection: some View {
        Group {
            sectionHeader("EXTENSION LOG (\(manager.extensionLog.count))")

            if manager.extensionLog.isEmpty {
                monoText("No extension callbacks received", opacity: 0.3)
            } else {
                ForEach(Array(manager.extensionLog.suffix(10).enumerated()), id: \.offset) { _, entry in
                    monoText(entry, opacity: 0.4)
                }
            }
        }
    }

    // MARK: - App Log

    private var appLogSection: some View {
        Group {
            sectionHeader("APP LOG (\(manager.debugLog.count))")

            if manager.debugLog.isEmpty {
                monoText("No app log entries", opacity: 0.3)
            } else {
                ForEach(Array(manager.debugLog.suffix(12).enumerated()), id: \.offset) { _, entry in
                    monoText(entry, opacity: 0.35)
                }
            }
        }
    }

    // MARK: - Components

    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(.system(.caption2, design: .monospaced, weight: .bold))
            .foregroundStyle(.white.opacity(0.25))
            .padding(.top, 6)
    }

    private func monoText(_ text: String, opacity: Double) -> some View {
        Text(text)
            .font(.system(size: 9, design: .monospaced))
            .foregroundStyle(.white.opacity(opacity))
            .fixedSize(horizontal: false, vertical: true)
    }

    private func eventColor(_ type: PomodoroEvent.EventType) -> Color {
        switch type {
        case .started: Color(red: 0.30, green: 0.85, blue: 0.55)
        case .completed: Color(red: 0.30, green: 0.85, blue: 0.55)
        case .screenTimeThreshold: Color(red: 0.50, green: 0.70, blue: 1.0)
        case .distractionDetected: Color(red: 1.0, green: 0.75, blue: 0.25)
        case .interrupted: Color(red: 0.90, green: 0.35, blue: 0.40)
        }
    }

    private enum StatusLevel {
        case good, warning, bad

        var color: Color {
            switch self {
            case .good: Color(red: 0.30, green: 0.85, blue: 0.55)
            case .warning: Color(red: 1.0, green: 0.75, blue: 0.25)
            case .bad: Color(red: 0.90, green: 0.35, blue: 0.40)
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
                .foregroundStyle(.white.opacity(0.5))
                .layoutPriority(1)

            Spacer(minLength: 4)

            Text(value)
                .font(.system(size: 9, weight: .medium, design: .monospaced))
                .foregroundStyle(.white.opacity(0.7))
                .multilineTextAlignment(.trailing)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}
