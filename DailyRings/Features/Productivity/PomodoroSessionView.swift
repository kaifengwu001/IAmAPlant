import SwiftUI

struct PomodoroSessionView: View {
    let session: PomodoroSession

    private var statusColor: Color {
        session.isCompleted
            ? Color(red: 0.30, green: 0.85, blue: 0.55)
            : Color(red: 0.90, green: 0.35, blue: 0.40)
    }

    private var statusIcon: String {
        session.isCompleted ? "checkmark.circle.fill" : "xmark.circle.fill"
    }

    private var timeLabel: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        return formatter.string(from: session.startTime)
    }

    var body: some View {
        HStack(spacing: 12) {
            Circle()
                .fill(statusColor)
                .frame(width: 8, height: 8)

            VStack(alignment: .leading, spacing: 2) {
                Text(session.goalLabel)
                    .font(.system(.subheadline, design: .monospaced, weight: .medium))
                    .foregroundStyle(.white)

                HStack(spacing: 8) {
                    Text(session.category)
                        .font(.system(.caption2, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.4))

                    Text(timeLabel)
                        .font(.system(.caption2, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.4))
                }
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Text("\(session.durationMinutes)m")
                    .font(.system(.subheadline, design: .monospaced, weight: .medium))
                    .foregroundStyle(.white)

                if session.distractedSeconds > 0 {
                    Text("\(session.distractedSeconds / 60)m off")
                        .font(.system(.caption2, design: .monospaced))
                        .foregroundStyle(Color(red: 0.90, green: 0.35, blue: 0.40).opacity(0.7))
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }
}
