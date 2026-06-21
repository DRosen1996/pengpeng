import CoreLocation
import Foundation
import MapKit
import Observation
import SwiftUI

enum NearbySheetRoute: Identifiable, Equatable {
    case zoneDetail(SportZone)
    case userList(SportZone)
    case sportTopic(NearbyUser)

    var id: String {
        switch self {
        case .zoneDetail(let zone):
            "zone-\(zone.id)"
        case .userList(let zone):
            "users-\(zone.id)"
        case .sportTopic(let user):
            "topic-\(user.id)"
        }
    }

    static func == (lhs: NearbySheetRoute, rhs: NearbySheetRoute) -> Bool {
        lhs.id == rhs.id
    }
}

@MainActor
@Observable
final class NearbyViewModel {
    private let api: PengPengAPI
    private let workoutStore: TodayWorkoutStore
    private var hasCenteredMapOnUser = false

    var userCoordinate: CLLocationCoordinate2D = MockData.userCoordinate
    var zones: [SportZone] = MockData.sportZones
    var sameSportUsers: [NearbyUser] = []
    var activeSheet: NearbySheetRoute?
    var selectedTopic: SportTopic?
    var matchedUser: NearbyUser?
    var bumpSent = false
    var mapCameraPosition: MapCameraPosition = MockData.nearbyCameraPosition
    var highlightedZoneID: String?
    var isLoading = false
    var lastError: String?

    var todayWorkout: WorkoutSummary { workoutStore.displayWorkout }
    var hasTodayPresence: Bool { workoutStore.hasTodayPresence }
    var hasDisplayableWorkout: Bool { workoutStore.hasDisplayableWorkout }
    var nearbyBottomWorkoutState: NearbyBottomWorkoutState { workoutStore.nearbyBottomWorkoutState }

    var defaultBumpZone: SportZone {
        zones.first(where: { $0.sport == todayWorkout.sport }) ?? MockData.strengthZone
    }

    var sportTopics: [SportTopic] { MockData.sportTopics }

    var isAuthenticated: Bool { api.isAuthenticated }

    init(api: PengPengAPI, workoutStore: TodayWorkoutStore) {
        self.api = api
        self.workoutStore = workoutStore
    }

    convenience init() {
        let api = PengPengAPI()
        self.init(
            api: api,
            workoutStore: TodayWorkoutStore(
                api: api,
                healthKit: HealthKitService(),
                location: LocationService()
            )
        )
        sameSportUsers = MockData.sameSportUsers
    }

    func load() async {
        await refreshUserLocation()
        await workoutStore.refresh()

        guard api.isAuthenticated else {
            sameSportUsers = []
            do {
                let presences = try await api.fetchTodayPresences()
                zones = PBMapping.sportZones(from: presences)
                lastError = nil
            } catch {
                zones = PBMapping.sportZones(from: [])
                lastError = error.localizedDescription
            }
            return
        }

        isLoading = true
        defer { isLoading = false }

        do {
            let presences = try await api.fetchTodayPresences()
            zones = PBMapping.sportZones(from: presences)
            sameSportUsers = try await api.fetchNearbyUsers(sport: todayWorkout.sport)
            lastError = nil
        } catch {
            lastError = error.localizedDescription
            sameSportUsers = []
        }
    }

    func requestHealthAccess() async {
        await workoutStore.requestHealthAccess()
    }

    func refreshUserLocation() async {
        let coordinate = await workoutStore.resolveMapCoordinate()
        userCoordinate = coordinate

        guard !hasCenteredMapOnUser, highlightedZoneID == nil else { return }
        hasCenteredMapOnUser = true
        withMapAnimation {
            mapCameraPosition = Self.nearbyCameraPosition(center: coordinate)
        }
    }

    static func nearbyCameraPosition(center: CLLocationCoordinate2D) -> MapCameraPosition {
        .camera(
            MapCamera(
                centerCoordinate: center,
                distance: 9_500,
                heading: 0,
                pitch: 0
            )
        )
    }

    func loadUsers(for zone: SportZone) async {
        guard api.isAuthenticated else {
            sameSportUsers = MockData.sameSportUsers
            return
        }

        do {
            sameSportUsers = try await api.fetchNearbyUsers(sport: zone.sport)
        } catch {
            lastError = error.localizedDescription
        }
    }

    func openZone(_ zone: SportZone) {
        highlightedZoneID = zone.id
        withMapAnimation {
            mapCameraPosition = focusCamera(for: zone)
        }
        activeSheet = .zoneDetail(zone)
    }

    func focusCamera(for zone: SportZone) -> MapCameraPosition {
        .camera(zone.focusCamera)
    }

    func clearZoneHighlight() {
        highlightedZoneID = nil
    }

    func resetMapFocus() {
        highlightedZoneID = nil
        withMapAnimation {
            mapCameraPosition = Self.nearbyCameraPosition(center: userCoordinate)
        }
    }

    func openUserList(for zone: SportZone) {
        activeSheet = .userList(zone)
        Task { await loadUsers(for: zone) }
    }

    func openDefaultBumpFlow() {
        openUserList(for: defaultBumpZone)
    }

    func bump(user: NearbyUser) {
        matchedUser = user
        selectedTopic = nil
        bumpSent = false
        activeSheet = .sportTopic(user)
    }

    func selectTopic(_ topic: SportTopic?) {
        selectedTopic = topic
    }

    func markBumpSent() {
        bumpSent = true
    }

    func conversation(for topic: SportTopic) -> [TopicMessage] {
        guard let user = matchedUser else { return [] }
        return MockData.topicConversation(for: topic, partner: user)
    }

    func dismissSheet() {
        activeSheet = nil
        bumpSent = false
        selectedTopic = nil
        matchedUser = nil
    }

    private func withMapAnimation(_ updates: () -> Void) {
        withAnimation(.easeInOut(duration: 0.45)) {
            updates()
        }
    }
}
