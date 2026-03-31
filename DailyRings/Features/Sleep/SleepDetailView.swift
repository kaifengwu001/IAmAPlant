import SwiftUI
import SwiftData

struct SleepDetailView: View {
    let selectedDate: Date
    var isToday: Bool = true

    @Environment(\.modelContext) private var modelContext
    @Environment(SupabaseService.self) private var supabaseService
    @Query private var summaries: [DailySummary]

    @State private var sleepManager = SleepManager()
    @State private var showManualAdjustment = false

    private var dateString: String {
        DateBoundary.dateString(from: selectedDate)
    }

    private var currentSummary: DailySummary? {
        summaries.first { $0.dateString == dateString }
    }

    var body: some View {
        VStack(spacing: 0) {
            if isToday {
                SleepSessionView()
                    .environment(sleepManager)
                Divider().background(Theme.border).padding(.horizontal, 20)
            }

            if let summary = currentSummary {
                sleepSummary(summary)
            }

            detectedGapsSection

            manualLogButton

            Spacer()
        }
        .sheet(isPresented: $showManualAdjustment) {
            SleepManualAdjustmentView(selectedDate: selectedDate)
        }
        .onAppear {
            let rtService = RescueTimeService(supabaseService: supabaseService)
            sleepManager.configure(modelContext: modelContext, rescueTimeService: rtService)
            Task { await sleepManager.checkForSleepGaps() }
        }
    }

    private func sleepSummary(_ summary: DailySummary) -> some View {
        VStack(spacing: 16) {
            HStack(spacing: 32) {
                statItem(label: "Duration", value: String(format: "%.1fh", summary.sleepHours))
                statItem(label: "Screen", value: "\(summary.sleepScreenMinutes)m")
                statItem(label: "Score", value: String(format: "%.0f%%", summary.sleepScore * 100))
            }
            .padding(.vertical, 16)

            if let start = summary.sleepStart, let end = summary.sleepEnd {
                sleepTimeline(start: start, end: end)
            }
        }
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
    }

    private func sleepTimeline(start: Date, end: Date) -> some View {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"

        return HStack {
            Text(formatter.string(from: start))
                .font(.system(.caption, design: .monospaced))
                .foregroundStyle(Theme.textSecondary)

            GeometryReader { geo in
                RoundedRectangle(cornerRadius: 4)
                    .fill(Theme.sleep.opacity(0.3))
                    .frame(height: 8)
                    .overlay(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Theme.sleep)
                            .frame(width: geo.size.width, height: 8)
                    }
            }
            .frame(height: 8)

            Text(formatter.string(from: end))
                .font(.system(.caption, design: .monospaced))
                .foregroundStyle(Theme.textSecondary)
        }
    }

    private var manualLogButton: some View {
        Button {
            showManualAdjustment = true
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "plus.circle")
                    .font(.system(size: 14))
                Text("Log Sleep Manually")
                    .font(.system(.caption, design: .monospaced, weight: .medium))
            }
            .foregroundStyle(Theme.textSecondary)
            .padding(.vertical, 12)
        }
    }

    // MARK: - Detected Gaps

    private var detectedGapsSection: some View {
        VStack(spacing: 8) {
            if sleepManager.isLoading {
                ProgressView()
                    .tint(Theme.textSecondary)
                    .padding()
            }

            ForEach(sleepManager.detectedGaps, id: \.start) { gap in
                gapCard(gap)
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 12)
    }

    private func gapCard(_ gap: DetectedGap) -> some View {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"

        return VStack(alignment: .leading, spacing: 8) {
            Text("Were you sleeping?")
                .font(.system(.caption, design: .monospaced, weight: .bold))
                .foregroundStyle(Theme.textSecondary)

            Text("\(formatter.string(from: gap.start)) – \(formatter.string(from: gap.end)) (\(String(format: "%.1f", gap.durationHours))h)")
                .font(.system(.subheadline, design: .monospaced))
                .foregroundStyle(Theme.textPrimary)

            HStack(spacing: 12) {
                Button("Yes, log it") {
                    Task {
                        await sleepManager.confirmSleepSession(
                            start: gap.start,
                            end: gap.end,
                            source: .autoDetected
                        )
                        sleepManager.dismissGap(gap)
                    }
                }
                .font(.system(.caption, design: .monospaced, weight: .medium))
                .foregroundStyle(Theme.sleep)

                Button("Dismiss") {
                    sleepManager.dismissGap(gap)
                }
                .font(.system(.caption, design: .monospaced))
                .foregroundStyle(Theme.textTertiary)
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Theme.surfacePrimary)
                .stroke(Theme.sleep.opacity(0.2), lineWidth: 1)
        )
    }
}
