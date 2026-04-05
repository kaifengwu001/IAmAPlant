import SwiftUI
import SwiftData
import PhotosUI

struct NutritionView: View {
    let selectedDate: Date
    var isToday: Bool = true

    @Environment(\.modelContext) private var modelContext
    @Environment(SupabaseService.self) private var supabaseService
    @Query private var summaries: [DailySummary]

    @State private var scoringService = MealScoringService()
    @State private var photoStore = MealPhotoStore()
    @State private var showCamera = false
    @State private var showPhotoPicker = false
    @State private var photoPickerItem: PhotosPickerItem?
    @State private var photoFilenames: [String] = []
    @State private var thumbnailCache: [String: UIImage] = [:]
    @State private var editingMeal: MealScore?
    @State private var editedDescription = ""
    @State private var isRescoring = false

    private var dateString: String {
        DateBoundary.dateString(from: selectedDate)
    }

    private var currentSummary: DailySummary? {
        summaries.first { $0.dateString == dateString }
    }

    private var mealScores: [MealScore] {
        currentSummary?.mealScores ?? []
    }

    var body: some View {
        VStack(spacing: 0) {
            scoreSummary

            Divider().background(Theme.border).padding(.horizontal, 20)

            if isToday {
                captureButtons
                Divider().background(Theme.border).padding(.horizontal, 20)
            }

            mealsList

            Spacer()
        }
        .onAppear {
            scoringService.configure(supabaseService: supabaseService)
            loadPhotos()
            loadThumbnails()
        }
        .onChange(of: mealScores.count) { _, _ in
            loadThumbnails()
        }
        .fullScreenCover(isPresented: $showCamera) {
            MealCameraView { image in
                Task { await handleCapturedImage(image) }
            }
        }
        .sheet(item: $editingMeal) { meal in
            mealEditSheet(meal: meal)
        }
    }

    // MARK: - Score Summary

    private var scoreSummary: some View {
        HStack(spacing: 24) {
            VStack(spacing: 4) {
                let average = ScoreCalculator.nutritionAverage(mealScores: mealScores)
                Text(String(format: "%.1f", average))
                    .font(.system(.largeTitle, design: .monospaced, weight: .bold))
                    .foregroundStyle(Theme.textPrimary)
                + Text("/10")
                    .font(.system(.body, design: .monospaced))
                    .foregroundStyle(Theme.textTertiary)

                Text("avg score")
                    .font(.system(.caption2, design: .monospaced))
                    .foregroundStyle(Theme.textTertiary)
            }

            Spacer()

            VStack(spacing: 4) {
                Text("\(mealScores.count)")
                    .font(.system(.title2, design: .monospaced, weight: .bold))
                    .foregroundStyle(Theme.textPrimary)
                Text("meals")
                    .font(.system(.caption2, design: .monospaced))
                    .foregroundStyle(Theme.textTertiary)
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 20)
    }

    // MARK: - Capture

    private var captureButtons: some View {
        HStack(spacing: 16) {
            Button {
                showCamera = true
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "camera.fill")
                        .font(.system(size: 16))
                    Text("Take Photo")
                        .font(.system(.subheadline, design: .monospaced, weight: .medium))
                }
                .foregroundStyle(Theme.textPrimary)
                .padding(.horizontal, 24)
                .padding(.vertical, 12)
                .background(
                    Capsule()
                        .fill(Theme.nutrition)
                )
            }

            PhotosPicker(selection: $photoPickerItem, matching: .images) {
                HStack(spacing: 8) {
                    Image(systemName: "photo.on.rectangle")
                        .font(.system(size: 14))
                    Text("Import")
                        .font(.system(.subheadline, design: .monospaced, weight: .medium))
                }
                .foregroundStyle(Theme.textSecondary)
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
                .background(
                    Capsule()
                        .stroke(Theme.border, lineWidth: 1)
                )
            }
            .onChange(of: photoPickerItem) { _, newItem in
                Task { await handlePickerItem(newItem) }
            }
        }
        .padding(.vertical, 16)
    }

    // MARK: - Meals List

    private var mealsList: some View {
        VStack(spacing: 0) {
            ForEach(mealScores.prefix(6)) { meal in
                Button {
                    editedDescription = meal.briefDescription
                    editingMeal = meal
                } label: {
                    mealRow(meal)
                }
                .buttonStyle(.plain)
                Divider().background(Theme.border).padding(.horizontal, 20)
            }

            ForEach(Array(scoringService.pendingScores.prefix(3)), id: \.self) { filename in
                pendingRow(filename)
                Divider().background(Theme.border).padding(.horizontal, 20)
            }

            ForEach(Array(scoringService.scoringErrors), id: \.key) { filename, message in
                errorRow(message)
                Divider().background(Theme.border).padding(.horizontal, 20)
            }

            if mealScores.isEmpty && scoringService.pendingScores.isEmpty && scoringService.scoringErrors.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "fork.knife")
                        .font(.system(size: 32))
                        .foregroundStyle(Theme.textQuaternary)
                    Text("No meals logged today")
                        .font(.system(.subheadline, design: .monospaced))
                        .foregroundStyle(Theme.textTertiary)
                    Text("Take a photo of your meal to get started")
                        .font(.system(.caption, design: .monospaced))
                        .foregroundStyle(Theme.textQuaternary)
                }
                .padding(32)
            }
        }
    }

    private func mealRow(_ meal: MealScore) -> some View {
        HStack(spacing: 12) {
            if let image = loadThumbnail(meal.photoFilename) {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 48, height: 48)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            } else {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Theme.surfacePrimary)
                    .frame(width: 48, height: 48)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(meal.timeLabel)
                    .font(.system(.subheadline, design: .monospaced, weight: .medium))
                    .foregroundStyle(Theme.textPrimary)

                Text(meal.briefDescription)
                    .font(.system(.caption, design: .monospaced))
                    .foregroundStyle(Theme.textTertiary)
                    .lineLimit(2)
            }

            Spacer()

            Text(String(format: "%.1f", meal.score))
                .font(.system(.title3, design: .monospaced, weight: .bold))
                .foregroundStyle(scoreColor(meal.score))
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 10)
    }

    private func pendingRow(_ filename: String) -> some View {
        HStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 8)
                .fill(Theme.surfacePrimary)
                .frame(width: 48, height: 48)
                .overlay {
                    ProgressView()
                        .tint(Theme.textSecondary)
                        .scaleEffect(0.7)
                }

            Text("Scoring...")
                .font(.system(.subheadline, design: .monospaced))
                .foregroundStyle(Theme.textTertiary)

            Spacer()
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 10)
    }

    private func errorRow(_ message: String) -> some View {
        HStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 8)
                .fill(Theme.surfacePrimary)
                .frame(width: 48, height: 48)
                .overlay {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.system(size: 16))
                        .foregroundStyle(Theme.nutrition.opacity(0.7))
                }

            Text(message)
                .font(.system(.caption, design: .monospaced))
                .foregroundStyle(Theme.textSecondary)
                .lineLimit(2)

            Spacer()
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 10)
    }

    // MARK: - Helpers

    private func handleCapturedImage(_ image: UIImage) async {
        guard let filename = try? await photoStore.savePhoto(image, for: selectedDate) else { return }

        if let score = await scoringService.scorePhoto(filename: filename, timestamp: .now) {
            let summary = currentSummary ?? createSummary()
            var scores = summary.mealScores
            scores.append(score)
            summary.mealScores = scores
            summary.mealCount = scores.count
            summary.nutritionScore = ScoreCalculator.nutritionScore(mealScores: scores)
            try? modelContext.save()
        }

        loadPhotos()
    }

    private func handlePickerItem(_ item: PhotosPickerItem?) async {
        guard let item,
              let data = try? await item.loadTransferable(type: Data.self),
              let image = UIImage(data: data) else { return }

        await handleCapturedImage(image)
    }

    private func loadPhotos() {
        Task {
            photoFilenames = await photoStore.photosForDate(selectedDate)
        }
    }

    private func createSummary() -> DailySummary {
        let summary = DailySummary(date: selectedDate)
        modelContext.insert(summary)
        return summary
    }

    private func loadThumbnail(_ filename: String) -> UIImage? {
        thumbnailCache[filename]
    }

    private func loadThumbnails() {
        let filenames = mealScores.map(\.photoFilename)
        Task {
            for filename in filenames where thumbnailCache[filename] == nil {
                if let image = await photoStore.loadPhoto(filename: filename) {
                    thumbnailCache[filename] = image
                }
            }
        }
    }

    private func scoreColor(_ score: Double) -> Color {
        if score >= 7 { return Theme.accent }
        if score >= 4 { return Theme.textSecondary }
        return Theme.exercise
    }

    // MARK: - Meal Edit Sheet

    private func mealEditSheet(meal: MealScore) -> some View {
        NavigationStack {
            VStack(spacing: 24) {
                if let image = loadThumbnail(meal.photoFilename) {
                    Image(uiImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(maxHeight: 200)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }

                HStack {
                    Text("Score:")
                        .font(.system(.body, design: .monospaced))
                        .foregroundStyle(Theme.textSecondary)
                    Text(String(format: "%.1f", meal.score))
                        .font(.system(.title3, design: .monospaced, weight: .bold))
                        .foregroundStyle(scoreColor(meal.score))
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("Description")
                        .font(.system(.caption, design: .monospaced, weight: .medium))
                        .foregroundStyle(Theme.textSecondary)
                    TextField("Describe this meal", text: $editedDescription, axis: .vertical)
                        .font(.system(.body, design: .monospaced))
                        .foregroundStyle(Theme.textPrimary)
                        .lineLimit(3...6)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Theme.surfacePrimary)
                        )
                }

                if isRescoring {
                    HStack(spacing: 8) {
                        ProgressView()
                            .tint(Theme.textSecondary)
                            .scaleEffect(0.8)
                        Text("Re-evaluating...")
                            .font(.system(.caption, design: .monospaced))
                            .foregroundStyle(Theme.textTertiary)
                    }
                }

                Spacer()
            }
            .padding(24)
            .background(Theme.background)
            .navigationTitle("Edit Meal")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { editingMeal = nil }
                        .font(.system(.body, design: .monospaced))
                        .disabled(isRescoring)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save & Re-score") {
                        Task { await rescoreMeal(original: meal) }
                    }
                    .font(.system(.body, design: .monospaced, weight: .bold))
                    .disabled(isRescoring || editedDescription.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
        .preferredColorScheme(.light)
        .interactiveDismissDisabled(isRescoring)
    }

    private func rescoreMeal(original: MealScore) async {
        let trimmed = editedDescription.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        isRescoring = true
        defer { isRescoring = false }

        guard let updated = await scoringService.rescoreWithDescription(
            filename: original.photoFilename,
            correctedDescription: trimmed,
            timestamp: original.timestamp
        ) else { return }

        guard let summary = currentSummary else { return }
        var scores = summary.mealScores
        if let index = scores.firstIndex(where: { $0.id == original.id }) {
            scores[index] = updated
        }
        summary.mealScores = scores
        summary.nutritionScore = ScoreCalculator.nutritionScore(mealScores: scores)
        try? modelContext.save()

        editingMeal = nil
    }
}
