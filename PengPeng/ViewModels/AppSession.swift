import Foundation
import Observation

@MainActor
@Observable
final class AppSession {
    let api: PengPengAPI
    let workoutStore: TodayWorkoutStore
    var isAuthenticated: Bool
    var userName: String?
    var lastError: String?

    init(api: PengPengAPI = PengPengAPI()) {
        self.api = api
        self.workoutStore = TodayWorkoutStore(
            api: api,
            healthKit: HealthKitService(),
            location: LocationService()
        )
        self.isAuthenticated = api.isAuthenticated
        self.userName = api.currentUserName
    }

    func login(email: String, password: String) async -> Bool {
        do {
            try await api.login(email: email, password: password)
            await completeLogin()
            return true
        } catch {
            lastError = error.localizedDescription
            return false
        }
    }

    func loginWithApple(identityToken: String, fullName: String?) async -> Bool {
        do {
            try await api.loginWithApple(identityToken: identityToken, fullName: fullName)
            await completeLogin()
            return true
        } catch {
            lastError = error.localizedDescription
            return false
        }
    }

    func logout() {
        api.logout()
        isAuthenticated = false
        userName = nil
        Task { await workoutStore.refresh() }
    }

    func syncFromTokenStore() {
        isAuthenticated = api.isAuthenticated
        userName = api.currentUserName
    }

    private func completeLogin() async {
        isAuthenticated = true
        userName = api.currentUserName
        lastError = nil
        await workoutStore.refresh()
    }
}
