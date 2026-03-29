import SwiftUI
import SwiftData

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(SupabaseService.self) private var supabaseService
    @Query private var settings: [UserSettings]

    private var currentSettings: UserSettings {
        settings.first ?? UserSettings()
    }

    @State private var sleepGoal: Double = AppConstants.defaultSleepGoalHours
    @State private var exerciseGoal: Double = Double(AppConstants.defaultExerciseGoalMinutes)
    @State private var productivityGoal: Double = Double(AppConstants.defaultProductivityGoalMinutes)
    @State private var dayBoundary: Double = Double(AppConstants.defaultDayBoundaryHour)
    @State private var rescueTimeKey: String = ""
    @State private var photoRetention: Double = 7

    var body: some View {
        NavigationStack {
            Form {
                goalsSection
                integrationSection
                dataSection
                accountSection
            }
            .scrollContentBackground(.hidden)
            .background(Color.black)
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        saveSettings()
                        dismiss()
                    }
                    .font(.system(.body, design: .monospaced, weight: .medium))
                }
            }
            .onAppear { loadSettings() }
        }
        .preferredColorScheme(.dark)
    }

    // MARK: - Sections

    private var goalsSection: some View {
        Section {
            VStack(alignment: .leading, spacing: 8) {
                Text("Sleep: \(String(format: "%.1f", sleepGoal)) hours")
                    .font(.system(.subheadline, design: .monospaced))
                Slider(value: $sleepGoal, in: 4...12, step: 0.5)
            }
            .listRowBackground(Color.white.opacity(0.05))

            VStack(alignment: .leading, spacing: 8) {
                Text("Exercise: \(Int(exerciseGoal)) minutes")
                    .font(.system(.subheadline, design: .monospaced))
                Slider(value: $exerciseGoal, in: 10...120, step: 5)
            }
            .listRowBackground(Color.white.opacity(0.05))

            VStack(alignment: .leading, spacing: 8) {
                let hours = Int(productivityGoal) / 60
                let mins = Int(productivityGoal) % 60
                Text("Productivity: \(hours)h \(mins)m")
                    .font(.system(.subheadline, design: .monospaced))
                Slider(value: $productivityGoal, in: 60...720, step: 30)
            }
            .listRowBackground(Color.white.opacity(0.05))
        } header: {
            Text("Goals")
                .font(.system(.caption, design: .monospaced, weight: .bold))
        }
    }

    private var integrationSection: some View {
        Section {
            VStack(alignment: .leading, spacing: 8) {
                Text("RescueTime API Key")
                    .font(.system(.subheadline, design: .monospaced))
                SecureField("Paste your API key", text: $rescueTimeKey)
                    .font(.system(.caption, design: .monospaced))
                    .textContentType(.password)
            }
            .listRowBackground(Color.white.opacity(0.05))

            VStack(alignment: .leading, spacing: 8) {
                Text("Day Boundary: \(Int(dayBoundary)):00 AM")
                    .font(.system(.subheadline, design: .monospaced))
                Slider(value: $dayBoundary, in: 0...6, step: 1)
            }
            .listRowBackground(Color.white.opacity(0.05))
        } header: {
            Text("Integrations")
                .font(.system(.caption, design: .monospaced, weight: .bold))
        }
    }

    private var dataSection: some View {
        Section {
            VStack(alignment: .leading, spacing: 8) {
                Text("Photo Retention: \(Int(photoRetention)) days")
                    .font(.system(.subheadline, design: .monospaced))
                Slider(value: $photoRetention, in: 1...30, step: 1)
            }
            .listRowBackground(Color.white.opacity(0.05))
        } header: {
            Text("Data")
                .font(.system(.caption, design: .monospaced, weight: .bold))
        }
    }

    private var accountSection: some View {
        Section {
            if supabaseService.isAuthenticated {
                Button("Sign Out", role: .destructive) {
                    Task { try? await supabaseService.signOut() }
                }
                .font(.system(.subheadline, design: .monospaced))
            } else {
                Text("Sign in with Apple to sync data")
                    .font(.system(.subheadline, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.5))
            }
        } header: {
            Text("Account")
                .font(.system(.caption, design: .monospaced, weight: .bold))
        }
        .listRowBackground(Color.white.opacity(0.05))
    }

    // MARK: - Persistence

    private func loadSettings() {
        sleepGoal = currentSettings.sleepGoalHours
        exerciseGoal = Double(currentSettings.exerciseGoalMinutes)
        productivityGoal = Double(currentSettings.productivityGoalMinutes)
        dayBoundary = Double(currentSettings.dayBoundaryHour)
        rescueTimeKey = currentSettings.rescueTimeAPIKey ?? ""
        photoRetention = Double(currentSettings.mealPhotoRetentionDays)
    }

    private func saveSettings() {
        let updated = currentSettings.withUpdated(keyPath: \.sleepGoalHours, value: sleepGoal)
        updated.exerciseGoalMinutes = Int(exerciseGoal)
        updated.productivityGoalMinutes = Int(productivityGoal)
        updated.dayBoundaryHour = Int(dayBoundary)
        updated.rescueTimeAPIKey = rescueTimeKey.isEmpty ? nil : rescueTimeKey
        updated.mealPhotoRetentionDays = Int(photoRetention)

        if settings.isEmpty {
            modelContext.insert(updated)
        }

        try? modelContext.save()
    }
}
