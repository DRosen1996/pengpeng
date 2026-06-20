import CoreLocation
import Foundation
import Observation

enum NearbyBottomWorkoutState: Equatable {
    case loading
    case workout
    case needsHealthAuthorization
    case healthUnavailable
    case noCandidates
}

@MainActor
@Observable
final class TodayWorkoutStore {
    private let api: PengPengAPI
    private let healthKit: HealthKitService
    private let location: LocationService

    var candidates: [TodayWorkoutCandidate] = []
    var selectedCandidateID: String?
    var displayWorkout: WorkoutSummary = WorkoutSummary(
        sport: .traditionalStrength,
        durationMinutes: 0,
        energyKcal: 0,
        nearbySameSportCount: 0
    )
    var hasTodayPresence = false
    var healthKitAccess: HealthKitAccessState = .notDetermined
    var isSyncing = false
    var isLoading = false
    var lastError: String?

    var selectedCandidate: TodayWorkoutCandidate? {
        guard let selectedCandidateID else { return nil }
        return candidates.first { $0.id == selectedCandidateID }
    }

    var canSync: Bool {
        api.isAuthenticated && !hasTodayPresence && selectedCandidate != nil
    }

    var needsHealthAuthorization: Bool {
        api.isAuthenticated && healthKitAccess == .notDetermined
    }

    var healthKitUnavailable: Bool {
        api.isAuthenticated && healthKitAccess == .unavailable
    }

    var hasNoCandidates: Bool {
        api.isAuthenticated && healthKitAccess == .ready && !hasTodayPresence && candidates.isEmpty
    }

    var hasDisplayableWorkout: Bool {
        selectedCandidate != nil && displayWorkout.durationMinutes > 0
    }

    var nearbyBottomWorkoutState: NearbyBottomWorkoutState {
        if hasDisplayableWorkout { return .workout }
        if isLoading { return .loading }
        switch healthKitAccess {
        case .notDetermined:
            return .needsHealthAuthorization
        case .unavailable:
            return .healthUnavailable
        case .ready:
            return .noCandidates
        }
    }

    init(
        api: PengPengAPI,
        healthKit: HealthKitService,
        location: LocationService
    ) {
        self.api = api
        self.healthKit = healthKit
        self.location = location
        self.healthKitAccess = healthKit.accessState
    }

    func refresh() async {
        healthKitAccess = healthKit.accessState
        isLoading = true
        defer { isLoading = false }

        do {
            if healthKitAccess == .ready {
                candidates = try await healthKit.fetchTodayCandidates()
                restoreOrApplySelection()
            } else {
                candidates = []
                selectedCandidateID = nil
            }

            guard api.isAuthenticated else {
                hasTodayPresence = false
                updateDisplayWorkout(nearbyPresences: [])
                lastError = nil
                return
            }

            let presences = try await api.fetchTodayPresences()
            let mine = try await api.fetchMyTodayPresence()
            hasTodayPresence = mine != nil
            updateDisplayWorkout(nearbyPresences: presences)
            lastError = nil
        } catch {
            lastError = error.localizedDescription
            hasTodayPresence = false
            updateDisplayWorkout(nearbyPresences: [])
        }
    }

    func selectCandidate(_ id: String) {
        selectedCandidateID = id
        UserDefaults.standard.set(id, forKey: selectionStorageKey)
        Task {
            let presences: [PBPresenceRecord] = if api.isAuthenticated {
                (try? await api.fetchTodayPresences()) ?? []
            } else {
                []
            }
            updateDisplayWorkout(nearbyPresences: presences)
        }
    }

    func requestHealthAccess() async {
        do {
            try await healthKit.requestAuthorization()
            healthKitAccess = healthKit.accessState
            await refresh()
        } catch {
            lastError = error.localizedDescription
        }
    }

    func syncTodayPresence() async {
        guard canSync, let candidate = selectedCandidate else { return }

        isSyncing = true
        defer { isSyncing = false }

        do {
            let geohash = try await resolveGeohash()
            _ = try await api.upsertTodayPresence(
                sport: candidate.sport,
                durationMinutes: candidate.durationMinutes,
                energyKcal: candidate.energyKcal,
                geohash: geohash
            )
            await refresh()
            lastError = nil
        } catch {
            lastError = error.localizedDescription
        }
    }

    func healthKitDebugInfo() -> HealthKitDebugInfo {
        healthKit.debugInfo()
    }

    var locationAuthorizationStatus: CLAuthorizationStatus {
        location.authorizationStatus
    }

    func requestLocationAuthorization() {
        location.requestWhenInUseAuthorization()
    }

    func probeLocationDescription() async throws -> String {
        let coordinate = try await location.requestLocation().coordinate
        let geohash = Geohash.encode(
            latitude: coordinate.latitude,
            longitude: coordinate.longitude,
            precision: 5
        )
        return String(
            format: "(%.5f, %.5f) → geohash %@",
            coordinate.latitude,
            coordinate.longitude,
            geohash
        )
    }

    private func restoreOrApplySelection() {
        guard let latest = candidates.first else {
            selectedCandidateID = nil
            return
        }

        if candidates.count == 1 {
            selectedCandidateID = latest.id
            UserDefaults.standard.set(latest.id, forKey: selectionStorageKey)
            return
        }

        if let stored = UserDefaults.standard.string(forKey: selectionStorageKey),
           candidates.contains(where: { $0.id == stored }) {
            selectedCandidateID = stored
            return
        }

        selectedCandidateID = latest.id
        UserDefaults.standard.set(latest.id, forKey: selectionStorageKey)
    }

    private func updateDisplayWorkout(nearbyPresences: [PBPresenceRecord]) {
        guard let candidate = selectedCandidate else {
            displayWorkout = WorkoutSummary(
                sport: .traditionalStrength,
                durationMinutes: 0,
                energyKcal: 0,
                nearbySameSportCount: 0
            )
            return
        }

        let nearbyCount = nearbyPresences.filter { $0.sport == candidate.sport.rawValue }.count
        displayWorkout = candidate.toWorkoutSummary(nearbyCount: nearbyCount)
    }

    private func resolveGeohash() async throws -> String {
        if let location = try? await location.requestLocation() {
            return Geohash.encode(
                latitude: location.coordinate.latitude,
                longitude: location.coordinate.longitude,
                precision: 5
            )
        }

        if let profileHash = try? await api.fetchCurrentUser().geohash?
            .trimmingCharacters(in: .whitespacesAndNewlines),
           !profileHash.isEmpty {
            return String(profileHash.prefix(5))
        }

        return APIConfig.defaultGeohashPrefix
    }

    private var selectionStorageKey: String {
        let formatter = DateFormatter()
        formatter.calendar = Calendar.current
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return "selectedWorkoutID_\(formatter.string(from: Date()))"
    }
}
