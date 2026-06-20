import Foundation

final class TokenStore {
    static let shared = TokenStore()

    private let tokenKey = "pengpeng.auth.token"
    private let userIDKey = "pengpeng.auth.userID"
    private let userNameKey = "pengpeng.auth.userName"

    private init() {}

    var token: String? {
        get { UserDefaults.standard.string(forKey: tokenKey) }
        set { UserDefaults.standard.set(newValue, forKey: tokenKey) }
    }

    var userID: String? {
        get { UserDefaults.standard.string(forKey: userIDKey) }
        set { UserDefaults.standard.set(newValue, forKey: userIDKey) }
    }

    var userName: String? {
        get { UserDefaults.standard.string(forKey: userNameKey) }
        set { UserDefaults.standard.set(newValue, forKey: userNameKey) }
    }

    var isAuthenticated: Bool {
        token != nil && userID != nil
    }

    func save(token: String, userID: String, userName: String?) {
        self.token = token
        self.userID = userID
        self.userName = userName
    }

    func clear() {
        token = nil
        userID = nil
        userName = nil
    }
}
