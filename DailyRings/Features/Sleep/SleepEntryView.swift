import SwiftUI

struct SleepEntryView: View {
    let session: SleepSession
    var onTimesEdited: ((Date, Date) -> Void)?

    @Environment(\.modelContext) private var modelContext
    @State private var showEditSheet = false
    @State private var editStart = Date.now
    @State private var editEnd = Date.now

    private var sourceLabel: String {
        switch session.source {
        case .manual: "Manual"
        case .autoDetected: "Auto-detected"
        case .healthkit: "HealthKit"
        }
    }

    private var sourceIcon: String {
        switch session.source {
        case .manual: "hand.raised"
        case .autoDetected: "waveform.path.ecg"
        case .healthkit: "heart.fill"
        }
    }

    private var timeLabel: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        let start = formatter.string(from: session.startTime)
        let end = session.endTime.map { formatter.string(from: $0) } ?? "..."
        return "\(start) – \(end)"
    }

    private var correctedEnd: Date {
        if editEnd < editStart {
            return Calendar.current.date(byAdding: .day, value: 1, to: editEnd) ?? editEnd
        }
        return editEnd
    }

    var body: some View {
        Button {
            editStart = session.startTime
            editEnd = session.endTime ?? .now
            showEditSheet = true
        } label: {
            HStack(spacing: 12) {
                Circle()
                    .fill(Theme.sleep)
                    .frame(width: 8, height: 8)

                VStack(alignment: .leading, spacing: 2) {
                    Text(timeLabel)
                        .font(.system(.subheadline, design: .monospaced, weight: .medium))
                        .foregroundStyle(Theme.textPrimary)

                    HStack(spacing: 8) {
                        Label(sourceLabel, systemImage: sourceIcon)
                            .font(.system(.caption2, design: .monospaced))
                            .foregroundStyle(Theme.textTertiary)
                    }
                }

                Spacer()

                if let hours = session.durationHours {
                    Text(String(format: "%.1fh", hours))
                        .font(.system(.subheadline, design: .monospaced, weight: .medium))
                        .foregroundStyle(Theme.textPrimary)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
        }
        .buttonStyle(.plain)
        .sheet(isPresented: $showEditSheet) {
            editSheet
        }
    }

    private var editSheet: some View {
        NavigationStack {
            VStack(spacing: 24) {
                let hours = correctedEnd.timeIntervalSince(editStart) / 3600
                Text(String(format: "%.1f hours", hours))
                    .font(.system(.title, design: .monospaced, weight: .bold))
                    .foregroundStyle(Theme.textPrimary)

                DatePicker("Bedtime", selection: $editStart, displayedComponents: [.date, .hourAndMinute])
                    .font(.system(.body, design: .monospaced))

                DatePicker("Wake-up", selection: $editEnd, displayedComponents: [.date, .hourAndMinute])
                    .font(.system(.body, design: .monospaced))

                Spacer()
            }
            .padding(24)
            .background(Theme.background)
            .navigationTitle("Edit Sleep")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { showEditSheet = false }
                        .font(.system(.body, design: .monospaced))
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        session.startTime = editStart
                        session.endTime = correctedEnd
                        try? modelContext.save()
                        onTimesEdited?(editStart, correctedEnd)
                        showEditSheet = false
                    }
                    .font(.system(.body, design: .monospaced, weight: .bold))
                }
            }
        }
        .preferredColorScheme(.light)
    }
}
