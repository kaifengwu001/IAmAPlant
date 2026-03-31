import SwiftUI
import SwiftData

struct SleepManualAdjustmentView: View {
    let selectedDate: Date

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @State private var bedtime: Date
    @State private var wakeTime: Date

    init(selectedDate: Date) {
        self.selectedDate = selectedDate

        let calendar = Calendar.current
        let defaultBedtime = calendar.date(bySettingHour: 23, minute: 0, second: 0, of: selectedDate)
            ?? selectedDate
        let nextDay = calendar.date(byAdding: .day, value: 1, to: selectedDate) ?? selectedDate
        let defaultWakeTime = calendar.date(bySettingHour: 7, minute: 0, second: 0, of: nextDay)
            ?? nextDay

        _bedtime = State(initialValue: defaultBedtime)
        _wakeTime = State(initialValue: defaultWakeTime)
    }

    private var durationHours: Double {
        max(wakeTime.timeIntervalSince(bedtime) / 3600.0, 0)
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Text(String(format: "%.1f hours", durationHours))
                    .font(.system(.title, design: .monospaced, weight: .bold))
                    .foregroundStyle(.white)

                DatePicker("Bedtime", selection: $bedtime, displayedComponents: [.date, .hourAndMinute])
                    .font(.system(.body, design: .monospaced))

                DatePicker("Wake-up", selection: $wakeTime, displayedComponents: [.date, .hourAndMinute])
                    .font(.system(.body, design: .monospaced))

                Spacer()
            }
            .padding(24)
            .background(Color.black)
            .navigationTitle("Log Sleep")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .font(.system(.body, design: .monospaced))
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .font(.system(.body, design: .monospaced, weight: .bold))
                        .disabled(durationHours <= 0)
                }
            }
        }
        .preferredColorScheme(.dark)
    }

    private func save() {
        guard durationHours > 0 else { return }

        let session = SleepSession(startTime: bedtime, source: .manual)
        let ended = session.ended(at: wakeTime)
        modelContext.insert(ended)

        let score = ScoreCalculator.sleepScore(
            hours: durationHours,
            goalHours: AppConstants.defaultSleepGoalHours
        )

        let logicalDate = DateBoundary.logicalDate(for: wakeTime)

        do {
            let summary = try DailySummary.fetchOrCreate(for: logicalDate, in: modelContext)
            summary.sleepStart = bedtime
            summary.sleepEnd = wakeTime
            summary.sleepHours = durationHours
            summary.sleepScore = score
            summary.sleepSource = .manual
            try modelContext.save()
        } catch {
            return
        }

        dismiss()
    }
}
