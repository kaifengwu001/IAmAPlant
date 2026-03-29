import Foundation
import HealthKit

@Observable
final class HealthKitManager {
    private let store = HKHealthStore()

    private(set) var authorizationStatus: AuthStatus = .notDetermined
    private(set) var exerciseMinutes: Int = 0
    private(set) var workouts: [WorkoutSample] = []
    private(set) var isLoading = false
    private var hasRequestedAuth = false

    enum AuthStatus {
        case notDetermined
        case authorized
        case denied
        case unavailable
    }

    struct WorkoutSample: Identifiable {
        let id = UUID()
        let workoutType: String
        let startDate: Date
        let endDate: Date
        let durationMinutes: Int
        let caloriesBurned: Double?
    }

    // MARK: - Authorization

    func requestAuthorization() async {
        guard HKHealthStore.isHealthDataAvailable() else {
            authorizationStatus = .unavailable
            return
        }

        let readTypes: Set<HKObjectType> = [
            HKQuantityType(.appleExerciseTime),
            HKObjectType.workoutType(),
            HKCategoryType(.sleepAnalysis)
        ]

        do {
            try await store.requestAuthorization(toShare: [], read: readTypes)
            hasRequestedAuth = true
            // HealthKit does NOT reveal read authorization status for privacy.
            // authorizationStatus(for:) only works for write/share types.
            // The only way to know if read access was granted is to attempt a query.
            // We optimistically set authorized after the prompt completes without error.
            authorizationStatus = .authorized
        } catch {
            authorizationStatus = .denied
        }
    }

    // MARK: - Queries

    func fetchExerciseData(for date: Date) async {
        if !hasRequestedAuth {
            await requestAuthorization()
        }
        guard authorizationStatus != .unavailable && authorizationStatus != .denied else { return }

        isLoading = true
        defer { isLoading = false }

        async let minutes = fetchExerciseMinutes(for: date)
        async let samples = fetchWorkoutSamples(for: date)

        exerciseMinutes = await minutes
        workouts = await samples

        // If we got data (or no error), we're authorized
        authorizationStatus = .authorized
    }

    private func fetchExerciseMinutes(for date: Date) async -> Int {
        let start = Calendar.current.startOfDay(for: date)
        guard let end = Calendar.current.date(byAdding: .day, value: 1, to: start) else { return 0 }

        let predicate = HKQuery.predicateForSamples(withStart: start, end: end, options: .strictStartDate)
        let exerciseType = HKQuantityType(.appleExerciseTime)

        return await withCheckedContinuation { continuation in
            let query = HKStatisticsQuery(
                quantityType: exerciseType,
                quantitySamplePredicate: predicate,
                options: .cumulativeSum
            ) { _, result, _ in
                let minutes = result?.sumQuantity()?.doubleValue(for: .minute()) ?? 0
                continuation.resume(returning: Int(minutes))
            }
            store.execute(query)
        }
    }

    private func fetchWorkoutSamples(for date: Date) async -> [WorkoutSample] {
        let start = Calendar.current.startOfDay(for: date)
        guard let end = Calendar.current.date(byAdding: .day, value: 1, to: start) else { return [] }

        let predicate = HKQuery.predicateForSamples(withStart: start, end: end, options: .strictStartDate)
        let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: true)

        return await withCheckedContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: HKObjectType.workoutType(),
                predicate: predicate,
                limit: HKObjectQueryNoLimit,
                sortDescriptors: [sortDescriptor]
            ) { _, samples, _ in
                guard let workouts = samples as? [HKWorkout] else {
                    continuation.resume(returning: [])
                    return
                }

                let results = workouts.map { workout in
                    WorkoutSample(
                        workoutType: workout.workoutActivityType.displayName,
                        startDate: workout.startDate,
                        endDate: workout.endDate,
                        durationMinutes: Int(workout.duration / 60),
                        caloriesBurned: workout.totalEnergyBurned?.doubleValue(for: .kilocalorie())
                    )
                }

                continuation.resume(returning: results)
            }
            store.execute(query)
        }
    }
}

extension HKWorkoutActivityType {
    var displayName: String {
        switch self {
        case .running: return "Running"
        case .walking: return "Walking"
        case .cycling: return "Cycling"
        case .swimming: return "Swimming"
        case .yoga: return "Yoga"
        case .hiking: return "Hiking"
        case .functionalStrengthTraining: return "Strength"
        case .traditionalStrengthTraining: return "Weights"
        case .highIntensityIntervalTraining: return "HIIT"
        case .dance: return "Dance"
        case .elliptical: return "Elliptical"
        case .rowing: return "Rowing"
        case .stairClimbing: return "Stairs"
        case .pilates: return "Pilates"
        default: return "Workout"
        }
    }
}
