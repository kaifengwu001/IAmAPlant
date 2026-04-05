import Foundation
import SwiftData

@Observable
final class SyncCoordinator {
    private let supabaseService: SupabaseService
    private var modelContext: ModelContext?

    private(set) var isSyncing = false
    private(set) var lastSyncDate: Date?

    init(supabaseService: SupabaseService) {
        self.supabaseService = supabaseService
    }

    func configure(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    // MARK: - Push Local → Remote

    func pushPendingChanges() async {
        guard supabaseService.isAuthenticated, let context = modelContext else { return }
        guard !isSyncing else { return }

        isSyncing = true
        defer { isSyncing = false }

        do {
            let syncedRaw = SyncStatus.synced.rawValue
            let descriptor = FetchDescriptor<DailySummary>(
                predicate: #Predicate { summary in
                    summary.statusRaw != syncedRaw
                }
            )
            let pending = try context.fetch(descriptor)

            for summary in pending {
                guard let userID = supabaseService.currentUserID else { continue }

                let dto = mapToDTO(summary, userID: userID)
                try await supabaseService.syncDailySummary(dto)

                summary.status = .synced
            }

            await pushPendingSessions()

            try context.save()
            lastSyncDate = .now
        } catch {
            // Sync failures are non-fatal; will retry next time
        }
    }

    // MARK: - Pomodoro Session Sync

    private func pushPendingSessions() async {
        guard let context = modelContext,
              let userID = supabaseService.currentUserID else { return }

        do {
            let descriptor = FetchDescriptor<PomodoroSession>(
                predicate: #Predicate { session in
                    session.isSynced == false && session.endTime != nil
                }
            )
            let pending = try context.fetch(descriptor)
            let formatter = ISO8601DateFormatter()

            for session in pending {
                let dto = PomodoroSessionDTO(
                    id: session.sessionID.uuidString,
                    user_id: userID,
                    date: session.dateString,
                    goal_label: session.goalLabel,
                    category: session.category,
                    start_time: formatter.string(from: session.startTime),
                    end_time: session.endTime.map { formatter.string(from: $0) },
                    completed: session.isCompleted,
                    distracted_seconds: session.distractedSeconds,
                    duration_minutes: session.durationMinutes
                )
                try await supabaseService.syncPomodoroSession(dto)
                session.isSynced = true
            }
        } catch {
            // Session sync failures are non-fatal
        }
    }

    func pullPomodoroSessions(for date: Date) async {
        guard supabaseService.isAuthenticated, let context = modelContext else { return }

        let logicalDate = DateBoundary.logicalDate(for: date)
        let dateStr = DateBoundary.dateString(from: logicalDate)

        do {
            let remoteSessions = try await supabaseService.fetchPomodoroSessions(date: dateStr)
            let formatter = ISO8601DateFormatter()

            for dto in remoteSessions {
                guard let sessionUUID = UUID(uuidString: dto.id) else { continue }

                let sessionID = sessionUUID
                let descriptor = FetchDescriptor<PomodoroSession>(
                    predicate: #Predicate { $0.sessionID == sessionID }
                )
                guard try context.fetch(descriptor).isEmpty else { continue }

                let session = PomodoroSession(
                    goalLabel: dto.goal_label,
                    category: dto.category,
                    date: logicalDate
                )
                session.sessionID = sessionUUID
                session.startTime = formatter.date(from: dto.start_time) ?? logicalDate
                session.endTime = dto.end_time.flatMap { formatter.date(from: $0) }
                session.isCompleted = dto.completed
                session.distractedSeconds = dto.distracted_seconds
                session.durationMinutes = dto.duration_minutes
                session.isSynced = true
                context.insert(session)
            }

            try context.save()
        } catch {
            // Pull session failures are non-fatal
        }
    }

    // MARK: - Pull Remote → Local

    func pullRecent(days: Int = 7) async {
        guard supabaseService.isAuthenticated, let context = modelContext else { return }

        let today = DateBoundary.today()
        for i in 0..<days {
            guard let date = Calendar.current.date(byAdding: .day, value: -i, to: today) else { continue }
            await pullLatest(for: date)
        }
    }

    func pullLatest(for date: Date) async {
        guard supabaseService.isAuthenticated, let context = modelContext else { return }

        let logicalDate = DateBoundary.logicalDate(for: date)
        let dateStr = DateBoundary.dateString(from: logicalDate)

        do {
            guard let remote = try await supabaseService.fetchDailySummary(date: dateStr) else { return }

            let descriptor = FetchDescriptor<DailySummary>(
                predicate: #Predicate { $0.dateString == dateStr }
            )
            let existing = try context.fetch(descriptor).first

            if let existing {
                if existing.status == .synced {
                    applyDTO(remote, to: existing)
                }
            } else {
                let summary = DailySummary(date: logicalDate)
                applyDTO(remote, to: summary)
                summary.status = .synced
                context.insert(summary)
            }

            try context.save()
        } catch {
            // Pull failures are non-fatal
        }

        await pullPomodoroSessions(for: date)
    }

    // MARK: - Sync Settings

    func syncSettings() async {
        guard supabaseService.isAuthenticated, let context = modelContext else { return }

        do {
            let descriptor = FetchDescriptor<UserSettings>()
            guard let local = try context.fetch(descriptor).first,
                  let userID = supabaseService.currentUserID else { return }

            let dto = UserSettingsDTO(
                user_id: userID,
                sleep_goal_hours: local.sleepGoalHours,
                exercise_goal_minutes: local.exerciseGoalMinutes,
                productivity_goal_minutes: local.productivityGoalMinutes,
                rescuetime_api_key: local.rescueTimeAPIKey,
                day_boundary_hour: local.dayBoundaryHour
            )

            try await supabaseService.syncUserSettings(dto)
        } catch {
            // Settings sync failure is non-fatal
        }
    }

    func pullSettings() async {
        guard supabaseService.isAuthenticated, let context = modelContext else { return }

        do {
            guard let remote = try await supabaseService.fetchUserSettings() else { return }

            let descriptor = FetchDescriptor<UserSettings>()
            let local = try context.fetch(descriptor).first

            if let local {
                local.sleepGoalHours = remote.sleep_goal_hours
                local.exerciseGoalMinutes = remote.exercise_goal_minutes
                local.productivityGoalMinutes = remote.productivity_goal_minutes
                local.rescueTimeAPIKey = remote.rescuetime_api_key
                local.dayBoundaryHour = remote.day_boundary_hour
                local.updatedAt = .now
            } else {
                let settings = UserSettings(userID: supabaseService.currentUserID ?? "local")
                settings.sleepGoalHours = remote.sleep_goal_hours
                settings.exerciseGoalMinutes = remote.exercise_goal_minutes
                settings.productivityGoalMinutes = remote.productivity_goal_minutes
                settings.rescueTimeAPIKey = remote.rescuetime_api_key
                settings.dayBoundaryHour = remote.day_boundary_hour
                context.insert(settings)
            }

            try context.save()
        } catch {
            // Pull settings failure is non-fatal
        }
    }

    // MARK: - Mapping

    private func mapToDTO(_ summary: DailySummary, userID: String) -> DailySummaryDTO {
        let formatter = ISO8601DateFormatter()

        return DailySummaryDTO(
            user_id: userID,
            date: summary.dateString,
            timezone: summary.timezone,
            sleep_start: summary.sleepStart.map { formatter.string(from: $0) },
            sleep_end: summary.sleepEnd.map { formatter.string(from: $0) },
            sleep_hours: summary.sleepHours,
            sleep_score: summary.sleepScore,
            sleep_screen_minutes: summary.sleepScreenMinutes,
            sleep_source: summary.sleepSource.rawValue,
            exercise_minutes: summary.exerciseMinutes,
            exercise_score: summary.exerciseScore,
            nutrition_score: summary.nutritionScore,
            meal_count: summary.mealCount,
            meal_scores: summary.mealScores,
            pomodoro_completed: summary.pomodoroCompleted,
            pomodoro_interrupted: summary.pomodoroInterrupted,
            pomodoro_total_minutes: summary.pomodoroTotalMinutes,
            rescuetime_productive_minutes: summary.rescueTimeProductiveMinutes,
            rescuetime_distracting_minutes: summary.rescueTimeDistractingMinutes,
            overlap_minutes: summary.overlapMinutes,
            manual_adjustment_minutes: summary.manualAdjustmentMinutes,
            manual_adjustments: summary.manualAdjustments,
            productive_minutes_total: summary.productiveMinutesTotal,
            productivity_score: summary.productivityScore,
            status: summary.status.rawValue
        )
    }

    private func applyDTO(_ dto: DailySummaryDTO, to summary: DailySummary) {
        let formatter = ISO8601DateFormatter()
        summary.sleepStart = dto.sleep_start.flatMap { formatter.date(from: $0) }
        summary.sleepEnd = dto.sleep_end.flatMap { formatter.date(from: $0) }
        summary.sleepHours = dto.sleep_hours
        summary.sleepScore = dto.sleep_score
        summary.sleepScreenMinutes = dto.sleep_screen_minutes
        summary.sleepSource = SleepSource(rawValue: dto.sleep_source) ?? .manual
        summary.exerciseMinutes = dto.exercise_minutes
        summary.exerciseScore = dto.exercise_score
        summary.nutritionScore = dto.nutrition_score
        summary.mealCount = dto.meal_count
        if let meals = dto.meal_scores {
            summary.mealScoresData = try? JSONEncoder().encode(meals)
        }
        summary.pomodoroCompleted = dto.pomodoro_completed
        summary.pomodoroInterrupted = dto.pomodoro_interrupted
        summary.pomodoroTotalMinutes = dto.pomodoro_total_minutes
        summary.rescueTimeProductiveMinutes = dto.rescuetime_productive_minutes
        summary.rescueTimeDistractingMinutes = dto.rescuetime_distracting_minutes
        summary.overlapMinutes = dto.overlap_minutes
        summary.manualAdjustmentMinutes = dto.manual_adjustment_minutes
        if let adj = dto.manual_adjustments {
            summary.manualAdjustmentsData = try? JSONEncoder().encode(adj)
        }
        summary.productiveMinutesTotal = dto.productive_minutes_total
        summary.productivityScore = dto.productivity_score
    }
}
