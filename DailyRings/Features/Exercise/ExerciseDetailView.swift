import SwiftUI
import SwiftData

struct ExerciseDetailView: View {
    let selectedDate: Date

    @Environment(\.modelContext) private var modelContext
    @State private var healthKitManager = HealthKitManager()
    @Query private var summaries: [DailySummary]

    private var dateString: String {
        DateBoundary.dateString(from: selectedDate)
    }

    private var currentSummary: DailySummary? {
        summaries.first { $0.dateString == dateString }
    }

    var body: some View {
        VStack(spacing: 0) {
            switch healthKitManager.authorizationStatus {
            case .unavailable:
                unavailableView
            case .denied:
                deniedView
            case .notDetermined:
                requestAuthView
            case .authorized:
                exerciseContent
            }
        }
        .onAppear {
            Task { await refreshExerciseData(for: selectedDate) }
        }
        .onChange(of: selectedDate) { _, newDate in
            Task { await refreshExerciseData(for: newDate) }
        }
    }

    // MARK: - Authorized Content

    private var exerciseContent: some View {
        VStack(spacing: 16) {
            progressBar

            Divider().background(Color.white.opacity(0.1))

            workoutsList
        }
    }

    private var progressBar: some View {
        VStack(spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("\(healthKitManager.exerciseMinutes)")
                        .font(.system(.largeTitle, design: .monospaced, weight: .bold))
                        .foregroundStyle(.white)
                    + Text(" min")
                        .font(.system(.body, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.5))

                    Text("of \(AppConstants.defaultExerciseGoalMinutes) min goal")
                        .font(.system(.caption, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.3))
                }

                Spacer()

                let score = currentSummary?.exerciseScore ?? ScoreCalculator.exerciseScore(
                    minutes: healthKitManager.exerciseMinutes,
                    goalMinutes: AppConstants.defaultExerciseGoalMinutes
                )
                Text(String(format: "%.0f%%", score * 100))
                    .font(.system(.title2, design: .monospaced, weight: .bold))
                    .foregroundStyle(Color(red: 0.30, green: 0.85, blue: 0.55))
            }
            .padding(.horizontal, 20)

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.white.opacity(0.08))
                        .frame(height: 8)

                    let progress = min(
                        Double(healthKitManager.exerciseMinutes) / Double(AppConstants.defaultExerciseGoalMinutes),
                        1.0
                    )
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color(red: 0.30, green: 0.85, blue: 0.55))
                        .frame(width: geo.size.width * progress, height: 8)
                        .animation(.spring(response: 0.5), value: progress)
                }
            }
            .frame(height: 8)
            .padding(.horizontal, 20)
        }
        .padding(.vertical, 20)
    }

    private var workoutsList: some View {
        VStack(spacing: 0) {
            if healthKitManager.isLoading {
                ProgressView()
                    .tint(.white.opacity(0.5))
                    .padding(32)
            } else if healthKitManager.workouts.isEmpty {
                emptyWorkoutsView
            } else {
                ForEach(healthKitManager.workouts) { workout in
                    workoutRow(workout)
                    Divider().background(Color.white.opacity(0.05))
                }
            }
        }
    }

    private func workoutRow(_ workout: HealthKitManager.WorkoutSample) -> some View {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"

        return HStack(spacing: 12) {
            Image(systemName: "figure.run")
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(Color(red: 0.30, green: 0.85, blue: 0.55))
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 2) {
                Text(workout.workoutType)
                    .font(.system(.subheadline, design: .monospaced, weight: .medium))
                    .foregroundStyle(.white)

                Text(formatter.string(from: workout.startDate))
                    .font(.system(.caption2, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.4))
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Text("\(workout.durationMinutes)m")
                    .font(.system(.subheadline, design: .monospaced, weight: .medium))
                    .foregroundStyle(.white)

                if let cal = workout.caloriesBurned {
                    Text("\(Int(cal)) cal")
                        .font(.system(.caption2, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.4))
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 10)
    }

    // MARK: - Permission States

    private var emptyWorkoutsView: some View {
        VStack(spacing: 8) {
            Image(systemName: "figure.run")
                .font(.system(size: 32))
                .foregroundStyle(.white.opacity(0.2))
            Text("No workouts recorded today")
                .font(.system(.subheadline, design: .monospaced))
                .foregroundStyle(.white.opacity(0.3))
        }
        .padding(32)
    }

    private var unavailableView: some View {
        VStack(spacing: 12) {
            Image(systemName: "applewatch.slash")
                .font(.system(size: 32))
                .foregroundStyle(.white.opacity(0.3))
            Text("HealthKit not available")
                .font(.system(.subheadline, design: .monospaced))
                .foregroundStyle(.white.opacity(0.5))
            Text("Exercise tracking requires an Apple Watch or manual workouts in the Health app.")
                .font(.system(.caption, design: .monospaced))
                .foregroundStyle(.white.opacity(0.3))
                .multilineTextAlignment(.center)
        }
        .padding(32)
    }

    private var deniedView: some View {
        VStack(spacing: 12) {
            Image(systemName: "lock.shield")
                .font(.system(size: 32))
                .foregroundStyle(.white.opacity(0.3))
            Text("Health access denied")
                .font(.system(.subheadline, design: .monospaced))
                .foregroundStyle(.white.opacity(0.5))
            Button("Open Settings") {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }
            .font(.system(.caption, design: .monospaced, weight: .medium))
            .foregroundStyle(Color(red: 0.30, green: 0.85, blue: 0.55))
        }
        .padding(32)
    }

    private var requestAuthView: some View {
        VStack(spacing: 12) {
            Image(systemName: "heart.text.square")
                .font(.system(size: 32))
                .foregroundStyle(.white.opacity(0.3))
            Text("Grant Health access to track exercise")
                .font(.system(.subheadline, design: .monospaced))
                .foregroundStyle(.white.opacity(0.5))
                .multilineTextAlignment(.center)
            Button("Allow Access") {
                Task { await healthKitManager.requestAuthorization() }
            }
            .font(.system(.caption, design: .monospaced, weight: .medium))
            .foregroundStyle(Color(red: 0.30, green: 0.85, blue: 0.55))
        }
        .padding(32)
    }
}

private extension ExerciseDetailView {
    func refreshExerciseData(for date: Date) async {
        await healthKitManager.fetchExerciseData(for: date)

        guard healthKitManager.authorizationStatus == .authorized else { return }

        do {
            let summary = try DailySummary.fetchOrCreate(for: date, in: modelContext)
            summary.updateExercise(minutes: healthKitManager.exerciseMinutes)
            try modelContext.save()
        } catch {
            // Keep showing live HealthKit data even if persistence fails.
        }
    }
}
