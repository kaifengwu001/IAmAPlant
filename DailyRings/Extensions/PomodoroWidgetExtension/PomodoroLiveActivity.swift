import ActivityKit
import SwiftUI
import WidgetKit

struct PomodoroLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: PomodoroActivityAttributes.self) { context in
            lockScreenView(context: context)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    HStack(spacing: 4) {
                        Image(systemName: categoryIcon(context.attributes.category))
                            .font(.system(size: 11))
                        Text(context.attributes.category)
                            .font(.system(.caption2, design: .monospaced))
                    }
                    .foregroundStyle(accentColor(for: context.state))
                }

                DynamicIslandExpandedRegion(.trailing) {
                    if context.state.phase == .running {
                        Text(timerInterval: timerRange(context: context), countsDown: true)
                            .font(.system(.title3, design: .monospaced, weight: .semibold))
                            .monospacedDigit()
                            .frame(maxWidth: .infinity, alignment: .trailing)
                    } else {
                        Text(phaseLabel(context.state.phase))
                            .font(.system(.caption, design: .monospaced, weight: .bold))
                            .foregroundStyle(phaseColor(context.state.phase))
                    }
                }

                DynamicIslandExpandedRegion(.bottom) {
                    VStack(spacing: 6) {
                        Text(context.attributes.goalLabel)
                            .font(.system(.subheadline, design: .monospaced, weight: .medium))
                            .lineLimit(1)

                        progressBar(context: context)
                            .frame(height: 4)
                    }
                    .padding(.top, 4)
                }

                DynamicIslandExpandedRegion(.center) {
                    EmptyView()
                }
            } compactLeading: {
                progressRingCompact(context: context)
                    .frame(width: 24, height: 24)
            } compactTrailing: {
                if context.state.phase == .running {
                    Text(timerInterval: timerRange(context: context), countsDown: true)
                        .font(.system(.caption, design: .monospaced, weight: .bold))
                        .monospacedDigit()
                        .frame(width: 48)
                } else {
                    Image(systemName: phaseIcon(context.state.phase))
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(phaseColor(context.state.phase))
                }
            } minimal: {
                progressRingMinimal(context: context)
                    .frame(width: 22, height: 22)
            }
        }
    }

    // MARK: - Timer

    private func timerRange(context: ActivityViewContext<PomodoroActivityAttributes>) -> ClosedRange<Date> {
        let start = context.state.endTime.addingTimeInterval(-Double(context.attributes.totalSeconds))
        let safeEnd = max(context.state.endTime, Date.now.addingTimeInterval(1))
        return start...safeEnd
    }

    private func progress(context: ActivityViewContext<PomodoroActivityAttributes>) -> Double {
        let total = Double(context.attributes.totalSeconds)
        let remaining = Double(context.state.remainingSeconds)
        return max(0, min(1.0 - remaining / total, 1.0))
    }

    // MARK: - Lock Screen

    private func lockScreenView(context: ActivityViewContext<PomodoroActivityAttributes>) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top, spacing: 0) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("POMODORO")
                        .font(.system(size: 16, weight: .bold, design: .monospaced))
                        .foregroundStyle(Color.white.opacity(0.6))
                    Text(context.attributes.category.uppercased())
                        .font(.system(size: 13, weight: .medium, design: .monospaced))
                        .foregroundStyle(Color.white.opacity(0.4))
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                Group {
                    if context.state.phase == .running {
                        Text(timerInterval: timerRange(context: context), countsDown: true)
                            .foregroundStyle(Color.white)
                    } else {
                        Text(phaseLabel(context.state.phase))
                            .foregroundStyle(phaseColor(context.state.phase))
                    }
                }
                .font(.system(size: 48, weight: .medium, design: .monospaced))
                .monospacedDigit()
                .multilineTextAlignment(.trailing)
                .frame(maxWidth: .infinity, alignment: .trailing)
                .padding(.top, -6)
                .padding(.bottom, -8)
            }

            Text(context.attributes.goalLabel)
                .font(.system(.body, design: .monospaced, weight: .medium))
                .foregroundStyle(Color.white)
                .lineLimit(1)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(20)
        .background(Color.black)
        .activityBackgroundTint(Color.black)
    }

    private func progressRingCompact(context: ActivityViewContext<PomodoroActivityAttributes>) -> some View {
        let prog = progress(context: context)
        let color = accentColor(for: context.state)

        return ZStack {
            Circle()
                .stroke(color.opacity(0.25), lineWidth: 2.5)

            Circle()
                .trim(from: 0, to: prog)
                .stroke(color, style: StrokeStyle(lineWidth: 2.5, lineCap: .round))
                .rotationEffect(.degrees(-90))
        }
    }

    private func progressRingMinimal(context: ActivityViewContext<PomodoroActivityAttributes>) -> some View {
        let prog = progress(context: context)
        let color = accentColor(for: context.state)

        return ZStack {
            Circle()
                .stroke(color.opacity(0.25), lineWidth: 2)

            Circle()
                .trim(from: 0, to: prog)
                .stroke(color, style: StrokeStyle(lineWidth: 2, lineCap: .round))
                .rotationEffect(.degrees(-90))
        }
    }

    // MARK: - Progress Bar

    private func progressBar(context: ActivityViewContext<PomodoroActivityAttributes>) -> some View {
        let prog = progress(context: context)
        let color = accentColor(for: context.state)

        return GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(color.opacity(0.2))

                Capsule()
                    .fill(color)
                    .frame(width: geo.size.width * prog)
            }
        }
    }

    // MARK: - Phase

    private func phaseLabel(_ phase: PomodoroActivityAttributes.Phase) -> String {
        switch phase {
        case .running: "Focus"
        case .completed: "Done"
        case .failed: "Failed"
        case .cancelled: "Stopped"
        }
    }

    private func phaseIcon(_ phase: PomodoroActivityAttributes.Phase) -> String {
        switch phase {
        case .running: "brain.head.profile"
        case .completed: "checkmark.circle.fill"
        case .failed: "xmark.circle.fill"
        case .cancelled: "stop.circle.fill"
        }
    }

    private func phaseColor(_ phase: PomodoroActivityAttributes.Phase) -> Color {
        switch phase {
        case .running: Palette.moss
        case .completed: Palette.herb
        case .failed: Color(red: 0.93, green: 0.48, blue: 0.07)
        case .cancelled: .secondary
        }
    }

    private func accentColor(for state: PomodoroActivityAttributes.ContentState) -> Color {
        guard state.phase == .running else {
            return phaseColor(state.phase)
        }
        return distractionColor(level: state.distractionLevel)
    }

    // MARK: - Helpers

    private func categoryIcon(_ category: String) -> String {
        switch category {
        case "Work": "briefcase.fill"
        case "Study": "book.fill"
        case "Creative": "paintbrush.fill"
        case "Admin": "folder.fill"
        case "Personal": "person.fill"
        default: "brain.head.profile"
        }
    }

    private func distractionIcon(level: Int) -> String {
        switch level {
        case 0: "brain.head.profile"
        case 1: "exclamationmark.triangle"
        case 2: "exclamationmark.triangle.fill"
        default: "xmark.octagon.fill"
        }
    }

    private func distractionColor(level: Int) -> Color {
        switch level {
        case 0: Palette.moss
        case 1: .yellow
        case 2: .orange
        default: .red
        }
    }
}

// MARK: - Palette (mirrors Theme from main app)

private enum Palette {
    static let moss = Color(red: 0.14, green: 0.24, blue: 0.00)
    static let parchment = Color(red: 0.95, green: 0.93, blue: 0.83)
    static let herb = Color(red: 0.42, green: 0.50, blue: 0.26)
}
