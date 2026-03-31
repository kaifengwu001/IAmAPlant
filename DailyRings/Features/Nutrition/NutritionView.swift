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

            Divider().background(Color.white.opacity(0.1))

            if isToday {
                captureButtons
                Divider().background(Color.white.opacity(0.1))
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
    }

    // MARK: - Score Summary

    private var scoreSummary: some View {
        HStack(spacing: 24) {
            VStack(spacing: 4) {
                let score = currentSummary?.nutritionScore ?? 0
                Text(String(format: "%.1f", score * 10))
                    .font(.system(.largeTitle, design: .monospaced, weight: .bold))
                    .foregroundStyle(.white)
                + Text("/10")
                    .font(.system(.body, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.4))

                Text("avg score")
                    .font(.system(.caption2, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.3))
            }

            Spacer()

            VStack(spacing: 4) {
                Text("\(mealScores.count)")
                    .font(.system(.title2, design: .monospaced, weight: .bold))
                    .foregroundStyle(.white)
                Text("meals")
                    .font(.system(.caption2, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.3))
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
                .foregroundStyle(.black)
                .padding(.horizontal, 24)
                .padding(.vertical, 12)
                .background(
                    Capsule()
                        .fill(Color(red: 0.95, green: 0.65, blue: 0.25))
                )
            }

            PhotosPicker(selection: $photoPickerItem, matching: .images) {
                HStack(spacing: 8) {
                    Image(systemName: "photo.on.rectangle")
                        .font(.system(size: 14))
                    Text("Import")
                        .font(.system(.subheadline, design: .monospaced, weight: .medium))
                }
                .foregroundStyle(.white.opacity(0.7))
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
                .background(
                    Capsule()
                        .stroke(Color.white.opacity(0.2), lineWidth: 1)
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
                mealRow(meal)
                Divider().background(Color.white.opacity(0.05))
            }

            ForEach(Array(scoringService.pendingScores.prefix(3)), id: \.self) { filename in
                pendingRow(filename)
                Divider().background(Color.white.opacity(0.05))
            }

            ForEach(Array(scoringService.scoringErrors), id: \.key) { filename, message in
                errorRow(message)
                Divider().background(Color.white.opacity(0.05))
            }

            if mealScores.isEmpty && scoringService.pendingScores.isEmpty && scoringService.scoringErrors.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "fork.knife")
                        .font(.system(size: 32))
                        .foregroundStyle(.white.opacity(0.2))
                    Text("No meals logged today")
                        .font(.system(.subheadline, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.3))
                    Text("Take a photo of your meal to get started")
                        .font(.system(.caption, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.2))
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
                    .fill(Color.white.opacity(0.05))
                    .frame(width: 48, height: 48)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(meal.timeLabel)
                    .font(.system(.subheadline, design: .monospaced, weight: .medium))
                    .foregroundStyle(.white)

                Text(meal.briefDescription)
                    .font(.system(.caption, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.4))
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
                .fill(Color.white.opacity(0.05))
                .frame(width: 48, height: 48)
                .overlay {
                    ProgressView()
                        .tint(.white.opacity(0.5))
                        .scaleEffect(0.7)
                }

            Text("Scoring...")
                .font(.system(.subheadline, design: .monospaced))
                .foregroundStyle(.white.opacity(0.4))

            Spacer()
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 10)
    }

    private func errorRow(_ message: String) -> some View {
        HStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.white.opacity(0.05))
                .frame(width: 48, height: 48)
                .overlay {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.system(size: 16))
                        .foregroundStyle(Theme.nutrition.opacity(0.7))
                }

            Text(message)
                .font(.system(.caption, design: .monospaced))
                .foregroundStyle(.white.opacity(0.5))
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
        if score >= 7 { return Color(red: 0.30, green: 0.85, blue: 0.55) }
        if score >= 4 { return Color(red: 0.95, green: 0.65, blue: 0.25) }
        return Color(red: 0.90, green: 0.35, blue: 0.40)
    }
}
