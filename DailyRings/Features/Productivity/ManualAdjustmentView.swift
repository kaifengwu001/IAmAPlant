import SwiftUI
import SwiftData

struct ManualAdjustmentView: View {
    let selectedDate: Date

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @State private var hours: Int = 0
    @State private var minutes: Int = 25
    @State private var note: String = ""
    @State private var isAdding = true

    private let hourRange = Array(0...8)
    private let minuteRange = stride(from: 0, through: 55, by: 5).map { $0 }

    private var totalMinutes: Int {
        hours * 60 + minutes
    }

    private var formattedDuration: String {
        if hours > 0 && minutes > 0 {
            return "\(hours)h \(minutes)m"
        } else if hours > 0 {
            return "\(hours)h"
        } else {
            return "\(minutes)m"
        }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Picker("Type", selection: $isAdding) {
                    Text("Add Time").tag(true)
                    Text("Subtract Time").tag(false)
                }
                .pickerStyle(.segmented)
                .padding(.horizontal, 24)
                .padding(.top, 24)

                durationLabel
                    .padding(.top, 28)

                timeWheels
                    .frame(height: 180)
                    .padding(.horizontal, 40)

                noteField
                    .padding(.horizontal, 24)
                    .padding(.top, 8)

                Spacer()
            }
            .background(Theme.background)
            .navigationTitle("Manual Adjustment")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .font(.system(.body, design: .monospaced))
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .font(.system(.body, design: .monospaced, weight: .bold))
                        .disabled(totalMinutes == 0 || note.isEmpty)
                }
            }
        }
        .preferredColorScheme(.light)
    }

    private var durationLabel: some View {
        HStack(spacing: 6) {
            Text(isAdding ? "+" : "−")
                .font(.system(size: 28, weight: .light, design: .monospaced))
                .foregroundStyle(isAdding ? Theme.accent : Theme.exercise)

            Text(formattedDuration)
                .font(.system(size: 28, weight: .light, design: .monospaced))
                .foregroundStyle(Theme.textPrimary)
        }
        .animation(.none, value: isAdding)
    }

    private var timeWheels: some View {
        HStack(spacing: 0) {
            Picker("Hours", selection: $hours) {
                ForEach(hourRange, id: \.self) { h in
                    Text("\(h) hr")
                        .font(.system(.title3, design: .monospaced))
                        .tag(h)
                }
            }
            .pickerStyle(.wheel)

            Picker("Minutes", selection: $minutes) {
                ForEach(minuteRange, id: \.self) { m in
                    Text("\(m) min")
                        .font(.system(.title3, design: .monospaced))
                        .tag(m)
                }
            }
            .pickerStyle(.wheel)
        }
    }

    private var noteField: some View {
        TextField("Note (required)", text: $note)
            .font(.system(.body, design: .monospaced))
            .foregroundStyle(Theme.textPrimary)
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Theme.surfacePrimary)
            )
    }

    private func save() {
        guard totalMinutes > 0, !note.isEmpty else { return }

        let adjustedMinutes = isAdding ? totalMinutes : -totalMinutes
        let adjustment = ManualAdjustment(minutes: adjustedMinutes, note: note)

        do {
            let summary = try DailySummary.fetchOrCreate(for: selectedDate, in: modelContext)
            let adjustments = summary.manualAdjustments + [adjustment]
            summary.manualAdjustments = adjustments

            _ = try DailySummary.refreshProductivity(for: selectedDate, in: modelContext)
            try modelContext.save()
        } catch {
            return
        }
        dismiss()
    }
}
