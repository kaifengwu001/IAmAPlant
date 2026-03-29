import SwiftUI

struct PomodoroTimerView: View {
    @Environment(PomodoroManager.self) private var pomodoroManager

    @State private var goalLabel = ""
    @State private var selectedCategory = "Work"

    private let categories = ["Work", "Study", "Creative", "Admin", "Personal"]

    var body: some View {
        VStack(spacing: 32) {
            if pomodoroManager.isRunning {
                activeTimerView
            } else {
                startSessionView
            }
        }
        .padding(24)
    }

    // MARK: - Active Timer

    private var activeTimerView: some View {
        VStack(spacing: 24) {
            if let session = pomodoroManager.activeSession {
                Text(session.goalLabel)
                    .font(.system(.caption, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.5))
            }

            timerRing

            Text(pomodoroManager.formattedTime)
                .font(.system(size: 48, weight: .light, design: .monospaced))
                .foregroundStyle(.white)

            Button {
                Task { await pomodoroManager.cancelSession() }
            } label: {
                Text("Cancel")
                    .font(.system(.subheadline, design: .monospaced, weight: .medium))
                    .foregroundStyle(Color(red: 0.90, green: 0.35, blue: 0.40))
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .background(
                        Capsule()
                            .stroke(Color(red: 0.90, green: 0.35, blue: 0.40).opacity(0.3), lineWidth: 1)
                    )
            }
        }
    }

    private var timerRing: some View {
        let totalSeconds = AppConstants.pomodoroWorkMinutes * 60
        let progress = 1.0 - Double(pomodoroManager.remainingSeconds) / Double(totalSeconds)

        return ZStack {
            Circle()
                .stroke(Color.white.opacity(0.08), lineWidth: 6)
                .frame(width: 160, height: 160)

            Circle()
                .trim(from: 0, to: progress)
                .stroke(
                    Color(red: 0.90, green: 0.35, blue: 0.40),
                    style: StrokeStyle(lineWidth: 6, lineCap: .round)
                )
                .frame(width: 160, height: 160)
                .rotationEffect(.degrees(-90))
                .animation(.linear(duration: 1), value: progress)
        }
    }

    // MARK: - Start Session

    private var startSessionView: some View {
        VStack(spacing: 20) {
            TextField("What are you working on?", text: $goalLabel)
                .font(.system(.body, design: .monospaced))
                .foregroundStyle(.white)
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.white.opacity(0.05))
                )

            categoryPicker

            Button {
                let label = goalLabel.isEmpty ? "Focus session" : goalLabel
                Task {
                    await pomodoroManager.startSession(label: label, category: selectedCategory)
                }
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "play.fill")
                        .font(.system(size: 14))
                    Text("Start \(AppConstants.pomodoroWorkMinutes) min")
                        .font(.system(.subheadline, design: .monospaced, weight: .medium))
                }
                .foregroundStyle(.black)
                .padding(.horizontal, 32)
                .padding(.vertical, 14)
                .background(
                    Capsule()
                        .fill(Color(red: 0.90, green: 0.35, blue: 0.40))
                )
            }
        }
    }

    private var categoryPicker: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(categories, id: \.self) { cat in
                    let isSelected = cat == selectedCategory
                    Button {
                        selectedCategory = cat
                    } label: {
                        Text(cat)
                            .font(.system(.caption, design: .monospaced, weight: isSelected ? .bold : .regular))
                            .foregroundStyle(isSelected ? .black : .white.opacity(0.6))
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                            .background(
                                Capsule()
                                    .fill(isSelected
                                          ? Color(red: 0.90, green: 0.35, blue: 0.40)
                                          : Color.white.opacity(0.08))
                            )
                    }
                }
            }
        }
    }
}
