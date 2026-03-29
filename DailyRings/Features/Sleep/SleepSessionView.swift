import SwiftUI

struct SleepSessionView: View {
    @Environment(SleepManager.self) private var sleepManager

    @State private var showEditTimes = false
    @State private var editStart = Date.now
    @State private var editEnd = Date.now

    var body: some View {
        VStack(spacing: 24) {
            if let session = sleepManager.activeSession {
                activeSleepView(session: session)
            } else {
                startSleepView
            }
        }
        .padding(24)
    }

    // MARK: - Active Session

    private func activeSleepView(session: SleepSession) -> some View {
        VStack(spacing: 20) {
            Image(systemName: "moon.fill")
                .font(.system(size: 40))
                .foregroundStyle(Color(red: 0.40, green: 0.55, blue: 0.90))

            Text("Sleeping...")
                .font(.system(.title3, design: .monospaced, weight: .medium))
                .foregroundStyle(.white)

            let elapsed = session.elapsedSinceStart
            let hours = Int(elapsed) / 3600
            let minutes = (Int(elapsed) % 3600) / 60
            Text("\(hours)h \(minutes)m elapsed")
                .font(.system(.subheadline, design: .monospaced))
                .foregroundStyle(.white.opacity(0.5))

            Button {
                editStart = session.startTime
                editEnd = .now
                showEditTimes = true
            } label: {
                Text("I'm Awake")
                    .font(.system(.subheadline, design: .monospaced, weight: .medium))
                    .foregroundStyle(.black)
                    .padding(.horizontal, 32)
                    .padding(.vertical, 14)
                    .background(
                        Capsule()
                            .fill(Color(red: 0.40, green: 0.55, blue: 0.90))
                    )
            }
        }
        .sheet(isPresented: $showEditTimes) {
            sleepEditSheet
        }
    }

    // MARK: - Start Sleep

    private var startSleepView: some View {
        VStack(spacing: 16) {
            Image(systemName: "moon.zzz")
                .font(.system(size: 32))
                .foregroundStyle(.white.opacity(0.3))

            Button {
                sleepManager.startSleepSession()
            } label: {
                Text("I'm Going to Sleep")
                    .font(.system(.subheadline, design: .monospaced, weight: .medium))
                    .foregroundStyle(.black)
                    .padding(.horizontal, 32)
                    .padding(.vertical, 14)
                    .background(
                        Capsule()
                            .fill(Color(red: 0.40, green: 0.55, blue: 0.90))
                    )
            }
        }
    }

    // MARK: - Edit Sheet

    private var sleepEditSheet: some View {
        NavigationStack {
            VStack(spacing: 24) {
                let hours = editEnd.timeIntervalSince(editStart) / 3600
                Text(String(format: "%.1f hours", hours))
                    .font(.system(.title, design: .monospaced, weight: .bold))
                    .foregroundStyle(.white)

                DatePicker("Bedtime", selection: $editStart, displayedComponents: [.hourAndMinute])
                    .font(.system(.body, design: .monospaced))

                DatePicker("Wake-up", selection: $editEnd, displayedComponents: [.hourAndMinute])
                    .font(.system(.body, design: .monospaced))

                Spacer()
            }
            .padding(24)
            .background(Color.black)
            .navigationTitle("Confirm Sleep")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Confirm") {
                        Task {
                            _ = await sleepManager.endSleepSession()
                            showEditTimes = false
                        }
                    }
                    .font(.system(.body, design: .monospaced, weight: .bold))
                }
            }
        }
        .preferredColorScheme(.dark)
    }
}
