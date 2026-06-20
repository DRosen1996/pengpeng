import Foundation
import Observation

@MainActor
@Observable
final class ProfileViewModel {
    private let api: PengPengAPI

    var userName: String = MockData.currentUserName
    var tags: [String] = MockData.profileTags
    var isLoading = false
    var lastError: String?

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
            lastError = nil
        } catch {
            lastError = error.localizedDescription
        }
    }
}
