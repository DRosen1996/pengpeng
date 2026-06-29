import CoreLocation
import Foundation
import Observation

@MainActor
@Observable
final class DeveloperDebugViewModel {
    private let session: AppSession
    private let conversationStore: ConversationStore

    var snapshot: DeveloperDebugSnapshot?
    var isLoading = false
    var locationProbeResult: String?
    var isProbingLocation = false
    var actionMessage: String?
    var showLocationPicker = false
    var isUpdatingLocation = false
    var locationPickerSessionID = 0
    var isAuthenticated: Bool { session.isAuthenticated }
    private var lastPickedCoordinate: CLLocationCoordinate2D?
    private var profileGeohash: String?

    init(session: AppSession, conversationStore: ConversationStore) {
        self.session = session
        self.conversationStore = conversationStore
    }

    func refresh() async {
        isLoading = true
        defer { isLoading = false }

        if session.isAuthenticated {
            if let user = try? await session.api.fetchCurrentUser(),
               let geohash = user.geohash?.trimmingCharacters(in: .whitespacesAndNewlines),
               !geohash.isEmpty {
                profileGeohash = geohash
            } else {
                profileGeohash = nil
            }
        } else {
            profileGeohash = nil
        }

        await session.workoutStore.refresh()
        snapshot = buildSnapshot()
    }

    func requestHealthAccess() async {
        await session.workoutStore.requestHealthAccess()
        snapshot = buildSnapshot()
        actionMessage = "已触发 HealthKit 授权弹窗"
    }

    func requestLocationAccess() {
        session.workoutStore.requestLocationAuthorization()
        actionMessage = "已触发位置授权弹窗"
        Task {
            try? await Task.sleep(nanoseconds: 500_000_000)
            snapshot = buildSnapshot()
        }
    }

    func probeLocation() async {
        isProbingLocation = true
        defer { isProbingLocation = false }

        do {
            locationProbeResult = try await session.workoutStore.probeLocationDescription()
            actionMessage = "定位探测成功"
        } catch {
            locationProbeResult = "失败：\(error.localizedDescription)"
            actionMessage = nil
        }
        snapshot = buildSnapshot()
    }

    func openLocationPicker() {
        guard session.isAuthenticated else {
            actionMessage = "请先登录后再修改定位"
            return
        }
        locationPickerSessionID += 1
        showLocationPicker = true
    }

    var locationPickerInitialCoordinate: CLLocationCoordinate2D {
        if let lastPickedCoordinate {
            return lastPickedCoordinate
        }
        if let profileGeohash,
           let coordinate = Geohash.decodeCoordinate(String(profileGeohash.prefix(5))) {
            return coordinate
        }
        if let coordinate = Geohash.decodeCoordinate(APIConfig.defaultGeohashPrefix) {
            return coordinate
        }
        return MockData.userCoordinate
    }

    func updateUserLocation(at coordinate: CLLocationCoordinate2D) async {
        guard session.isAuthenticated else {
            actionMessage = "请先登录后再修改定位"
            return
        }

        let geohash = Geohash.encode(
            latitude: coordinate.latitude,
            longitude: coordinate.longitude,
            precision: 5
        )

        if geohash == profileGeohash {
            actionMessage = "Geohash 未变化（仍为 \(geohash)），请拖动地图到其他区域后再保存"
            return
        }

        isUpdatingLocation = true
        defer { isUpdatingLocation = false }

        do {
            let updatedPresence = try await session.workoutStore.updateTodayPresenceLocation(geohash: geohash)
            lastPickedCoordinate = coordinate

            if let user = try? await session.api.fetchCurrentUser(),
               let serverGeohash = user.geohash?.trimmingCharacters(in: .whitespacesAndNewlines),
               !serverGeohash.isEmpty {
                profileGeohash = serverGeohash
            } else {
                profileGeohash = geohash
            }

            await session.workoutStore.refresh()
            showLocationPicker = false
            actionMessage = updatedPresence
                ? "已更新 Profile 与今日 presence geohash：\(profileGeohash ?? geohash)"
                : "已更新 Profile geohash：\(profileGeohash ?? geohash)（今日无 presence）"
            snapshot = buildSnapshot()
        } catch {
            actionMessage = "更新定位失败：\(error.localizedDescription)"
        }
    }

    private func buildSnapshot() -> DeveloperDebugSnapshot {
        let store = session.workoutStore
        let health = store.healthKitDebugInfo()
        let workout = store.displayWorkout

        let permissionRows: [DeveloperDebugSnapshot.Row] = [
            .init(id: "hk-available", label: "HealthKit 可用", value: health.isAvailable ? "是" : "否"),
            .init(id: "hk-state", label: "HealthKit 状态", value: health.accessState.displayName),
            .init(id: "hk-requested", label: "已弹出 Health 授权", value: health.authorizationRequested ? "是" : "否"),
            .init(id: "hk-workout", label: "训练读取 (HK)", value: health.workoutAuthorization),
            .init(id: "hk-energy", label: "活动能量读取 (HK)", value: health.activeEnergyAuthorization),
            .init(id: "loc-auth", label: "位置授权", value: store.locationAuthorizationStatus.displayName)
        ]

        let workoutRows: [DeveloperDebugSnapshot.Row] = [
            .init(id: "candidates", label: "今日候选数", value: "\(store.candidates.count)"),
            .init(id: "selected", label: "选中训练 ID", value: store.selectedCandidateID ?? "—"),
            .init(id: "presence", label: "已同步 presence", value: store.hasTodayPresence ? "是" : "否"),
            .init(id: "bypass", label: "presence 回填", value: store.usesPresenceBypass ? "是" : "否"),
            .init(id: "can-sync", label: "可同步", value: store.canSync ? "是" : "否"),
            .init(
                id: "display",
                label: "展示摘要",
                value: "\(workout.sport.title) · \(workout.durationMinutes) 分钟 · \(workout.energyKcal) kcal"
            ),
            .init(id: "nearby", label: "附近同项目", value: "\(workout.nearbySameSportCount) 人"),
            .init(id: "store-error", label: "Store 错误", value: store.lastError ?? "—")
        ]

        let locationRows: [DeveloperDebugSnapshot.Row] = [
            .init(id: "profile-geohash", label: "Profile geohash", value: profileGeohash ?? "—"),
            .init(id: "default-geohash", label: "默认 geohash", value: APIConfig.defaultGeohashPrefix),
            .init(id: "probe", label: "定位探测", value: locationProbeResult ?? "未探测")
        ]

        let accountRows: [DeveloperDebugSnapshot.Row] = [
            .init(id: "auth", label: "登录状态", value: session.isAuthenticated ? "已登录" : "未登录"),
            .init(id: "user-id", label: "User ID", value: session.api.currentUserID ?? "—"),
            .init(id: "user-name", label: "用户名", value: session.userName ?? "—")
        ]

        let realtimeRows: [DeveloperDebugSnapshot.Row] = [
            .init(id: "rt-status", label: "Realtime 状态", value: conversationStore.realtimeStatus),
            .init(id: "rt-error", label: "消息 Store 错误", value: conversationStore.lastError ?? "—"),
            .init(id: "rt-log", label: "Realtime 日志", value: conversationStore.realtimeDebugSummary)
        ]

        return DeveloperDebugSnapshot(
            permissionRows: permissionRows,
            workoutRows: workoutRows,
            locationRows: locationRows,
            accountRows: accountRows,
            realtimeRows: realtimeRows
        )
    }
}
