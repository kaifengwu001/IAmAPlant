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
                score: response.score,
                briefDescription: response.brief_description,
                photoFilename: filename
            )
            scoringErrors.removeValue(forKey: filename)
            return score
        } catch {
            scoringErrors[filename] = Self.friendlyError(from: error)
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

    func clearError(for filename: String) {
        scoringErrors.removeValue(forKey: filename)
    }

    private static func friendlyError(from error: Error) -> String {
        let message = error.localizedDescription.lowercased()
        if message.contains("422") || message.contains("no food") {
            return "No food detected in this photo. Try a clearer shot."
        }
        if message.contains("401") || message.contains("unauthorized") {
            return "Not signed in. Sign in and try again."
        }
        if message.contains("500") || message.contains("internal server") {
            return "Scoring failed. Try again in a moment."
        }
        if message.contains("timeout") || message.contains("timed out") {
            return "Request timed out. Check your connection."
        }
        if message.contains("non-2xx") || message.contains("edge function") {
            return "Could not score this photo. Try again."
        }
        return "Something went wrong. Try again."
    }
}
