import Foundation

enum APIConfig {
    /// PocketBase 服务地址（HTTP 内测；正式环境请换 HTTPS 域名）
    static let baseURL = URL(string: "http://1.14.226.184")!

    static let usersCollection = "users"
    static let presenceCollection = "presence"
    static let bumpsCollection = "bumps"
    static let conversationsCollection = "conversations"
    static let messagesCollection = "messages"

    /// 联调阶段默认 geohash（深圳湾 mock 区，精度 5 ≈ 2.4km）
    static let defaultGeohashPrefix = "ws10e"

    static var useMockFallback: Bool { false }
}
