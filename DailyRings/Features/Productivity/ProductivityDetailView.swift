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

    private var dateString: String {
        DateBoundary.dateString(from: selectedDate)
    }

    private var todaySessions: [PomodoroSession] {
        sessions.filter { $0.dateString == dateString }
            .sorted { $0.startTime > $1.startTime }
    }

    private var currentSummary: DailySummary? {
        summaries.first { $0.dateString == dateString }
    }

    var body: some View {
        ScrollView {
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

                Divider().background(Color.white.opacity(0.1))

                summaryBar

                Divider().background(Color.white.opacity(0.1))

                sessionsList

                manualAdjustButton
            }
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
            .foregroundStyle(.white.opacity(0.25))
            .padding(.vertical, 6)
        }
    }

    private var pastDayBanner: some View {
        VStack(spacing: 8) {
            Image(systemName: "clock.arrow.circlepath")
                .font(.system(size: 28))
                .foregroundStyle(.white.opacity(0.2))
            Text("Viewing past day")
                .font(.system(.caption, design: .monospaced))
                .foregroundStyle(.white.opacity(0.3))
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
                value: formatMinutes(completedSessions.count * AppConstants.pomodoroWorkMinutes)
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
                .foregroundStyle(.white)
            Text(label)
                .font(.system(.caption2, design: .monospaced))
                .foregroundStyle(.white.opacity(0.4))
        }
        .frame(maxWidth: .infinity)
    }

    private var sessionsList: some View {
        VStack(spacing: 0) {
            ForEach(todaySessions.prefix(5), id: \.sessionID) { session in
                PomodoroSessionView(session: session)
                Divider().background(Color.white.opacity(0.05))
            }

            if todaySessions.isEmpty {
                Text("No sessions yet today")
                    .font(.system(.subheadline, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.3))
                    .padding(.vertical, 32)
            }

            if todaySessions.count > 5 {
                Text("+\(todaySessions.count - 5) more")
                    .font(.system(.caption, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.3))
                    .padding(.vertical, 8)
            }
        }
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
            .foregroundStyle(.white.opacity(0.5))
            .padding(.vertical, 12)
        }
    }

    private func formatMinutes(_ minutes: Int) -> String {
        let h = minutes / 60
        let m = minutes % 60
        return h > 0 ? "\(h)h \(m)m" : "\(m)m"
    }
}
