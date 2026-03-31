import SwiftUI
import SwiftData

struct ProductivityDetailView: View {
    let selectedDate: Date
    var isToday: Bool = true

    @Environment(\.modelContext) private var modelContext
    @Environment(PomodoroManager.self) private var pomodoroManager
    @Query private var sessions: [PomodoroSession]
    @Query private var summaries: [DailySummary]

    @State private var showManualAdjustment = false
    @State private var showDebugPanel = false
    @State private var showAllSessions = false

    private var dateString: String {
        DateBoundary.dateString(from: selectedDate)
    }

    private var todaySessions: [PomodoroSession] {
        sessions.filter { $0.dateString == dateString && $0.endTime != nil }
            .sorted { $0.startTime > $1.startTime }
    }

    private var currentSummary: DailySummary? {
        summaries.first { $0.dateString == dateString }
    }

    var body: some View {
        VStack(spacing: 0) {
            if isToday {
                PomodoroTimerView()
                    .environment(pomodoroManager)
            } else {
                pastDayBanner
            }

            if isToday {
                debugToggle
                if showDebugPanel {
                    PomodoroDebugStatusView()
                        .environment(pomodoroManager)
                        .padding(.vertical, 8)
                }
            }

            Divider().background(Theme.border).padding(.horizontal, 20)

            summaryBar

            Divider().background(Theme.border).padding(.horizontal, 20)

            sessionsList

            manualAdjustmentsList

            manualAdjustButton
        }
        .sheet(isPresented: $showManualAdjustment) {
            ManualAdjustmentView(selectedDate: selectedDate)
        }
    }

    private var debugToggle: some View {
        Button {
            withAnimation(.easeInOut(duration: 0.2)) {
                showDebugPanel.toggle()
            }
        } label: {
            HStack(spacing: 4) {
                Image(systemName: "ant.fill")
                    .font(.system(size: 9))
                Text(showDebugPanel ? "Hide Debug" : "Show Debug")
                    .font(.system(.caption2, design: .monospaced))
                Image(systemName: showDebugPanel ? "chevron.up" : "chevron.down")
                    .font(.system(size: 8))
            }
            .foregroundStyle(Theme.textQuaternary)
            .padding(.vertical, 6)
        }
    }

    private var pastDayBanner: some View {
        VStack(spacing: 8) {
            Image(systemName: "clock.arrow.circlepath")
                .font(.system(size: 28))
                .foregroundStyle(Theme.textQuaternary)
            Text("Viewing past day")
                .font(.system(.caption, design: .monospaced))
                .foregroundStyle(Theme.textTertiary)
        }
        .padding(.vertical, 24)
    }

    private var completedSessions: [PomodoroSession] {
        todaySessions.filter(\.isCompleted)
    }

    private var summaryBar: some View {
        HStack(spacing: 20) {
            statItem(
                label: "Pomodoros",
                value: "\(completedSessions.count)"
            )
            statItem(
                label: "Productive",
                value: formatMinutes(currentSummary?.productiveMinutesTotal ?? completedSessions.count * AppConstants.pomodoroWorkMinutes)
            )
            statItem(
                label: "Score",
                value: String(format: "%.0f%%", (currentSummary?.productivityScore ?? 0) * 100)
            )
        }
        .padding(.vertical, 16)
        .padding(.horizontal, 20)
    }

    private func statItem(label: String, value: String) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.system(.title3, design: .monospaced, weight: .bold))
                .foregroundStyle(Theme.textPrimary)
            Text(label)
                .font(.system(.caption2, design: .monospaced))
                .foregroundStyle(Theme.textTertiary)
        }
        .frame(maxWidth: .infinity)
    }

    private var visibleSessions: [PomodoroSession] {
        showAllSessions ? todaySessions : Array(todaySessions.prefix(5))
    }

    private var sessionsList: some View {
        VStack(spacing: 0) {
            ForEach(visibleSessions, id: \.sessionID) { session in
                PomodoroSessionView(session: session)
                Divider().background(Theme.border).padding(.horizontal, 20)
            }

            if todaySessions.isEmpty {
                Text("No sessions yet today")
                    .font(.system(.subheadline, design: .monospaced))
                    .foregroundStyle(Theme.textTertiary)
                    .padding(.vertical, 32)
            }

            if todaySessions.count > 5 {
                Button {
                    withAnimation(.easeInOut(duration: 0.25)) {
                        showAllSessions.toggle()
                    }
                } label: {
                    HStack(spacing: 4) {
                        Text(showAllSessions ? "Show less" : "+\(todaySessions.count - 5) more")
                            .font(.system(.caption, design: .monospaced))
                        Image(systemName: showAllSessions ? "chevron.up" : "chevron.down")
                            .font(.system(size: 8, weight: .bold))
                    }
                    .foregroundStyle(Theme.textTertiary)
                    .padding(.vertical, 8)
                }
            }
        }
    }

    private var manualAdjustmentsList: some View {
        let adjustments = currentSummary?.manualAdjustments ?? []

        return VStack(spacing: 0) {
            ForEach(adjustments) { adjustment in
                manualAdjustmentRow(adjustment)
                Divider().background(Theme.border).padding(.horizontal, 20)
            }
        }
    }

    private func manualAdjustmentRow(_ adjustment: ManualAdjustment) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(adjustment.note)
                    .font(.system(.subheadline, design: .monospaced))
                    .foregroundStyle(Theme.textPrimary)
                Text(formatTimestamp(adjustment.timestamp))
                    .font(.system(.caption2, design: .monospaced))
                    .foregroundStyle(Theme.textTertiary)
            }

            Spacer()

            Text(adjustment.minutes > 0 ? "+\(adjustment.minutes)m" : "\(adjustment.minutes)m")
                .font(.system(.subheadline, design: .monospaced, weight: .medium))
                .foregroundStyle(adjustment.minutes > 0 ? Theme.accent : Theme.exercise)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
    }

    private func formatTimestamp(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        return formatter.string(from: date)
    }

    private var manualAdjustButton: some View {
        Button {
            showManualAdjustment = true
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "plus.circle")
                    .font(.system(size: 14))
                Text("Manual Adjustment")
                    .font(.system(.caption, design: .monospaced, weight: .medium))
            }
            .foregroundStyle(Theme.textSecondary)
            .padding(.vertical, 12)
        }
    }

    private func formatMinutes(_ minutes: Int) -> String {
        let h = minutes / 60
        let m = minutes % 60
        return h > 0 ? "\(h)h \(m)m" : "\(m)m"
    }
}
