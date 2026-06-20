import Foundation
import HealthKit

final class HealthKitService {
    private let store = HKHealthStore()
    private let minimumDurationMinutes = 15

    var accessState: HealthKitAccessState {
        guard HKHealthStore.isHealthDataAvailable() else { return .unavailable }
        return UserDefaults.standard.bool(forKey: Self.requestedKey) ? .ready : .notDetermined
    }

    var isAuthorizationRequested: Bool {
        UserDefaults.standard.bool(forKey: Self.requestedKey)
    }

    func debugInfo() -> HealthKitDebugInfo {
        let workoutStatus = store.authorizationStatus(for: HKObjectType.workoutType())
        let energyStatus: HKAuthorizationStatus = {
            guard let energy = HKObjectType.quantityType(forIdentifier: .activeEnergyBurned) else {
                return .notDetermined
            }
            return store.authorizationStatus(for: energy)
        }()

        return HealthKitDebugInfo(
            isAvailable: HKHealthStore.isHealthDataAvailable(),
            accessState: accessState,
            authorizationRequested: isAuthorizationRequested,
            workoutAuthorization: workoutStatus.displayName,
            activeEnergyAuthorization: energyStatus.displayName
        )
    }

    private static let requestedKey = "healthKitAuthorizationRequested"

    private var readTypes: Set<HKObjectType> {
        var types = Set<HKObjectType>()
        types.insert(HKObjectType.workoutType())
        if let energy = HKObjectType.quantityType(forIdentifier: .activeEnergyBurned) {
            types.insert(energy)
        }
        return types
    }

    func requestAuthorization() async throws {
        guard HKHealthStore.isHealthDataAvailable() else { return }
        try await store.requestAuthorization(toShare: [], read: readTypes)
        UserDefaults.standard.set(true, forKey: Self.requestedKey)
    }

    func fetchTodayCandidates() async throws -> [TodayWorkoutCandidate] {
        guard HKHealthStore.isHealthDataAvailable() else { return [] }

        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: Date())
        guard let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay) else {
            return []
        }

        let predicate = HKQuery.predicateForSamples(
            withStart: startOfDay,
            end: endOfDay,
            options: .strictStartDate
        )

        let workouts = try await queryWorkouts(predicate: predicate)
        var candidates: [TodayWorkoutCandidate] = []

        for workout in workouts {
            guard let sport = workout.workoutActivityType.pengPengSport else { continue }

            let durationMinutes = Int(workout.duration / 60)
            guard durationMinutes >= minimumDurationMinutes else { continue }

            let energyKcal = try await energyKcal(for: workout)
            candidates.append(
                TodayWorkoutCandidate(
                    id: workout.uuid.uuidString,
                    sport: sport,
                    durationMinutes: durationMinutes,
                    energyKcal: energyKcal,
                    startDate: workout.startDate
                )
            )
        }

        return candidates.sorted { $0.startDate > $1.startDate }
    }

    private func queryWorkouts(predicate: NSPredicate) async throws -> [HKWorkout] {
        try await withCheckedThrowingContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: HKObjectType.workoutType(),
                predicate: predicate,
                limit: HKObjectQueryNoLimit,
                sortDescriptors: [NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)]
            ) { _, samples, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }
                let workouts = (samples as? [HKWorkout]) ?? []
                continuation.resume(returning: workouts)
            }
            store.execute(query)
        }
    }

    private func energyKcal(for workout: HKWorkout) async throws -> Int {
        if let burned = workout.totalEnergyBurned {
            return Int(burned.doubleValue(for: .kilocalorie()).rounded())
        }

        guard let energyType = HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned) else {
            return 0
        }

        let predicate = HKQuery.predicateForSamples(
            withStart: workout.startDate,
            end: workout.endDate,
            options: .strictStartDate
        )

        return try await withCheckedThrowingContinuation { continuation in
            let query = HKStatisticsQuery(
                quantityType: energyType,
                quantitySamplePredicate: predicate,
                options: .cumulativeSum
            ) { _, statistics, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }
                let kcal = statistics?.sumQuantity()?.doubleValue(for: .kilocalorie()) ?? 0
                continuation.resume(returning: Int(kcal.rounded()))
            }
            store.execute(query)
        }
    }
}
