import Foundation
import Observation

@MainActor
@Observable
final class AppSession {
    let api: PengPengAPI
    var isAuthenticated: Bool
    var userName: String?
    var lastError: String?

    init(api: PengPengAPI = PengPengAPI()) {
        self.api = api
        self.isAuthenticated = api.isAuthenticated
        self.userName = api.currentUserName
    }

    func login(email: String, password: String) async -> Bool {
        do {
            try await api.login(email: email, password: password)
            isAuthenticated = true
            userName = api.currentUserName
            lastError = nil
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
    }

    func syncFromTokenStore() {
        isAuthenticated = api.isAuthenticated
        userName = api.currentUserName
    }
}
