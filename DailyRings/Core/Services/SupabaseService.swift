import Foundation
import Supabase

@Observable
final class SupabaseService {
    private let client: SupabaseClient

    var isAuthenticated: Bool { currentUserID != nil }
    var currentUserID: String?

    init() {
        let supabaseURL = Self.infoValue(forKey: "SUPABASE_URL")
        let supabaseKey = Self.infoValue(forKey: "SUPABASE_ANON_KEY")
        let resolvedURL = URL(string: supabaseURL)

        guard let resolvedURL, resolvedURL.host != nil else {
            preconditionFailure(
                "Missing or invalid SUPABASE_URL. Check Config/Secrets.xcconfig, then clean and rebuild so Info.plist substitutes $(SUPABASE_URL)."
            )
        }

        guard !supabaseKey.isEmpty else {
            preconditionFailure(
                "Missing SUPABASE_ANON_KEY. Check Config/Secrets.xcconfig, then clean and rebuild so Info.plist substitutes $(SUPABASE_ANON_KEY)."
            )
        }

        self.client = SupabaseClient(
            supabaseURL: resolvedURL,
            supabaseKey: supabaseKey
        )
    }

    private static func infoValue(forKey key: String) -> String {
        let value = (Bundle.main.object(forInfoDictionaryKey: key) as? String)?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if value.hasPrefix("$(") || value.hasPrefix("${") {
            return ""
        }
        return value
    }

    // MARK: - Auth

    func signUp(email: String, password: String) async throws {
        let response = try await client.auth.signUp(email: email, password: password)
        currentUserID = response.user.id.uuidString
    }

    func signIn(email: String, password: String) async throws {
        let session = try await client.auth.signIn(email: email, password: password)
        currentUserID = session.user.id.uuidString
    }

    func signOut() async throws {
        try await client.auth.signOut()
        currentUserID = nil
    }

    func restoreSession() async {
        do {
            let session = try await client.auth.session
            currentUserID = session.user.id.uuidString
        } catch {
            currentUserID = nil
        }
    }

    // MARK: - Daily Summary Sync

    func syncDailySummary(_ summary: DailySummaryDTO) async throws {
        try await client
            .from("daily_summary")
            .upsert(summary, onConflict: "user_id,date")
            .execute()
    }

    func fetchDailySummary(date: String) async throws -> DailySummaryDTO? {
        guard let userID = currentUserID else { return nil }
        let response: [DailySummaryDTO] = try await client
            .from("daily_summary")
            .select()
            .eq("user_id", value: userID)
            .eq("date", value: date)
            .execute()
            .value
        return response.first
    }

    // MARK: - Edge Functions

    func scoreMeal(imageBase64: String, timestamp: Date) async throws -> MealScoreResponse {
        let iso = ISO8601DateFormatter().string(from: timestamp)
        let body = MealScoreRequest(image_base64: imageBase64, timestamp: iso)
        let response: MealScoreResponse = try await client.functions
            .invoke("score-meal", options: .init(body: body))
        return response
    }

    func fetchRescueTimeData(startDate: String, endDate: String, type: String) async throws -> RescueTimeResponse {
        let body = RescueTimeRequest(start_date: startDate, end_date: endDate, data_type: type)
        let response: RescueTimeResponse = try await client.functions
            .invoke("rescuetime-proxy", options: .init(body: body))
        return response
    }

    // MARK: - User Settings

    func syncUserSettings(_ settings: UserSettingsDTO) async throws {
        try await client
            .from("user_settings")
            .upsert(settings)
            .execute()
    }

    func fetchUserSettings() async throws -> UserSettingsDTO? {
        guard let userID = currentUserID else { return nil }
        let response: [UserSettingsDTO] = try await client
            .from("user_settings")
            .select()
            .eq("user_id", value: userID)
            .execute()
            .value
        return response.first
    }
}

// MARK: - DTOs

struct DailySummaryDTO: Codable {
    let user_id: String
    let date: String
    let timezone: String
    let sleep_start: String?
    let sleep_end: String?
    let sleep_hours: Double
    let sleep_score: Double
    let sleep_screen_minutes: Int
    let sleep_source: String
    let exercise_minutes: Int
    let exercise_score: Double
    let nutrition_score: Double
    let meal_count: Int
    let meal_scores: [MealScore]?
    let pomodoro_completed: Int
    let pomodoro_interrupted: Int
    let pomodoro_total_minutes: Int
    let rescuetime_productive_minutes: Int
    let rescuetime_distracting_minutes: Int
    let overlap_minutes: Int
    let manual_adjustment_minutes: Int
    let manual_adjustments: [ManualAdjustment]?
    let productive_minutes_total: Int
    let productivity_score: Double
    let status: String
}

struct UserSettingsDTO: Codable {
    let user_id: String
    let sleep_goal_hours: Double
    let exercise_goal_minutes: Int
    let productivity_goal_minutes: Int
    let rescuetime_api_key: String?
    let day_boundary_hour: Int
}

struct MealScoreRequest: Codable {
    let image_base64: String
    let timestamp: String
}

struct MealScoreResponse: Codable {
    let score: Double
    let brief_description: String
    let time: String
}

struct RescueTimeRequest: Codable {
    let start_date: String
    let end_date: String
    let data_type: String
}

struct RescueTimeResponse: Codable {
    let rows: [[RescueTimeEntry]]?
    let productive_minutes: Int?
    let distracting_minutes: Int?
    let activity_gaps: [ActivityGap]?
}

struct RescueTimeEntry: Codable {
    let timestamp: String
    let seconds: Int
    let activity: String
    let category: String
    let productivity: Int
}

struct ActivityGap: Codable {
    let start: String
    let end: String
    let duration_minutes: Int
}
