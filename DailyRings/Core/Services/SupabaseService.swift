import Foundation
import Supabase

@Observable
final class SupabaseService {
    private let client: SupabaseClient

    var isAuthenticated: Bool { currentUserID != nil }
    var currentUserID: String?

    init() {
        let supabaseURL = Bundle.main.infoDictionary?["SUPABASE_URL"] as? String ?? ""
        let supabaseKey = Bundle.main.infoDictionary?["SUPABASE_ANON_KEY"] as? String ?? ""

        self.client = SupabaseClient(
            supabaseURL: URL(string: supabaseURL) ?? URL(string: "https://placeholder.supabase.co")!,
            supabaseKey: supabaseKey
        )
    }

    // MARK: - Auth

    func signInWithApple(idToken: String, nonce: String) async throws {
        let session = try await client.auth.signInWithIdToken(
            credentials: .init(provider: .apple, idToken: idToken, nonce: nonce)
        )
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
        let body = MealScoreRequest(image_base64: imageBase64, timestamp: timestamp)
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
    let timestamp: Date
}

struct MealScoreResponse: Codable {
    let meal_type: String
    let time: String
    let score: Double
    let brief_description: String
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
