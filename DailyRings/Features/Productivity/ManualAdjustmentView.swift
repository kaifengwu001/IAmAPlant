import SwiftUI
import SwiftData

struct ManualAdjustmentView: View {
    let selectedDate: Date

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @State private var minutes: String = ""
    @State private var note: String = ""
    @State private var isAdding = true

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Picker("Type", selection: $isAdding) {
                    Text("Add Time").tag(true)
                    Text("Subtract Time").tag(false)
                }
                .pickerStyle(.segmented)

                TextField("Minutes", text: $minutes)
                    .font(.system(.title, design: .monospaced))
                    .keyboardType(.numberPad)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.white)

                TextField("Note (required)", text: $note)
                    .font(.system(.body, design: .monospaced))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.white.opacity(0.05))
                    )

                Spacer()
            }
            .padding(24)
            .background(Color.black)
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
                        .disabled(minutes.isEmpty || note.isEmpty)
                }
            }
        }
        .preferredColorScheme(.dark)
    }

    private func save() {
        guard let minuteValue = Int(minutes), !note.isEmpty else { return }

        let adjustedMinutes = isAdding ? minuteValue : -minuteValue
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
