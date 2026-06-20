import Foundation
import Observation

@MainActor
@Observable
final class ProfileViewModel {
    private let api: PengPengAPI

    var userName: String = MockData.currentUserName
    var tags: [String] = MockData.profileTags
    var todayWorkout: WorkoutSummary = MockData.todayWorkout
    var hasTodayPresence = false
    var isLoading = false
    var isSyncingPresence = false
    var lastError: String?

    /// 协议未提供统计字段，登录后暂以占位展示
    var weeklyWorkouts: Int { hasTodayPresence ? 1 : 0 }
    var activityRingPercent: Int {
        min(100, todayWorkout.energyKcal / 6)
    }

    init(api: PengPengAPI) {
        self.api = api
    }

    convenience init() {
        self.init(api: PengPengAPI())
    }

    func load() async {
        guard api.isAuthenticated else {
            userName = MockData.currentUserName
            tags = MockData.profileTags
            todayWorkout = MockData.todayWorkout
            hasTodayPresence = false
            return
        }

        isLoading = true
        defer { isLoading = false }

        do {
            let user = try await api.fetchCurrentUser()
            let trimmedName = user.name?.trimmingCharacters(in: .whitespacesAndNewlines)
            userName = (trimmedName?.isEmpty == false ? trimmedName : nil)
                ?? api.currentUserName
                ?? "运动者"
            if let userTags = user.tags, !userTags.isEmpty {
                tags = userTags
            }

            let presences = try await api.fetchTodayPresences()
            if let mine = try await api.fetchMyTodayPresence(),
               let workout = PBMapping.workoutSummary(
                   from: mine,
                   nearbyCount: presences.filter { $0.sport == mine.sport }.count
               ) {
                todayWorkout = workout
                hasTodayPresence = true
            } else {
                hasTodayPresence = false
            }
            lastError = nil
        } catch {
            lastError = error.localizedDescription
        }
    }

    func syncTodayPresence() async {
        guard api.isAuthenticated else { return }

        isSyncingPresence = true
        defer { isSyncingPresence = false }

        do {
            let geohash = (try? await api.fetchCurrentUser().geohash)?
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .nilIfEmpty
                ?? APIConfig.defaultGeohashPrefix
            _ = try await api.upsertTodayPresence(
                sport: todayWorkout.sport,
                durationMinutes: todayWorkout.durationMinutes,
                energyKcal: todayWorkout.energyKcal,
                geohash: geohash
            )
            await load()
            lastError = nil
        } catch {
            lastError = error.localizedDescription
        }
    }
}

private extension String {
    var nilIfEmpty: String? {
        isEmpty ? nil : self
    }
}
