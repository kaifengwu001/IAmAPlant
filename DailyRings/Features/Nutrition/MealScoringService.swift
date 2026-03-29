import Foundation

@Observable
final class MealScoringService {
    private let photoStore = MealPhotoStore()
    private var supabaseService: SupabaseService?

    private(set) var pendingScores: Set<String> = []
    private(set) var scoringErrors: [String: String] = [:]

    func configure(supabaseService: SupabaseService) {
        self.supabaseService = supabaseService
    }

    // MARK: - Auto-Score on Capture

    func scorePhoto(filename: String, timestamp: Date) async -> MealScore? {
        guard let service = supabaseService else { return nil }

        pendingScores.insert(filename)
        defer { pendingScores.remove(filename) }

        guard let base64 = await photoStore.loadBase64(filename: filename) else {
            scoringErrors[filename] = "Failed to load photo"
            return nil
        }

        do {
            let response = try await service.scoreMeal(imageBase64: base64, timestamp: timestamp)
            let score = MealScore(
                timestamp: timestamp,
                mealType: response.meal_type,
                score: response.score,
                briefDescription: response.brief_description,
                photoFilename: filename
            )
            scoringErrors.removeValue(forKey: filename)
            return score
        } catch {
            scoringErrors[filename] = error.localizedDescription
            return nil
        }
    }

    // MARK: - Batch Fallback

    func scoreAllPending(date: Date, existingScores: [MealScore]) async -> [MealScore] {
        let allPhotos = await photoStore.photosForDate(date)
        let scoredFilenames = Set(existingScores.map(\.photoFilename))
        let unscored = allPhotos.filter { !scoredFilenames.contains($0) }

        var newScores: [MealScore] = []
        for filename in unscored {
            if let score = await scorePhoto(filename: filename, timestamp: date) {
                newScores.append(score)
            }
        }

        return newScores
    }

    // MARK: - Photo Management

    func photosForDate(_ date: Date) async -> [String] {
        await photoStore.photosForDate(date)
    }

    func cleanupExpiredPhotos(retentionDays: Int) async {
        try? await photoStore.deleteExpiredPhotos(retentionDays: retentionDays)
    }
}
