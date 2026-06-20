import Foundation

enum PocketBaseError: LocalizedError {
    case invalidURL
    case unauthorized
    case httpStatus(Int, String)
    case decoding(Error)
    case missingData

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            "无效的 API 地址"
        case .unauthorized:
            "未登录或登录已过期"
        case .httpStatus(let code, let body):
            "请求失败 (\(code)): \(body)"
        case .decoding(let error):
            "数据解析失败: \(error.localizedDescription)"
        case .missingData:
            "响应数据缺失"
        }
    }
}

struct PBMessageResponse: Decodable {
    let message: String?
    let data: [String: String]?
}

final class PocketBaseClient {
    private let baseURL: URL
    private let tokenStore: TokenStore
    private let session: URLSession
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    init(
        baseURL: URL = APIConfig.baseURL,
        tokenStore: TokenStore = .shared,
        session: URLSession = .shared
    ) {
        self.baseURL = baseURL
        self.tokenStore = tokenStore
        self.session = session

        encoder = JSONEncoder()
        decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom(PocketBaseDate.decode)
    }

    var currentUserID: String? { tokenStore.userID }

    // MARK: - Auth

    func authWithPassword(identity: String, password: String) async throws -> PBAuthResponse {
        let body = ["identity": identity, "password": password]
        let response: PBAuthResponse = try await request(
            method: "POST",
            path: "/api/collections/\(APIConfig.usersCollection)/auth-with-password",
            body: body,
            authenticated: false
        )
        saveAuthResponse(response)
        return response
    }

    func authWithApple(identityToken: String, fullName: String?) async throws -> PBAuthResponse {
        struct Body: Encodable {
            let identityToken: String
            let fullName: String?
        }
        let response: PBAuthResponse = try await request(
            method: "POST",
            path: APIConfig.appleAuthPath,
            body: Body(identityToken: identityToken, fullName: fullName),
            authenticated: false
        )
        saveAuthResponse(response)
        return response
    }

    func logout() {
        tokenStore.clear()
    }

    private func saveAuthResponse(_ response: PBAuthResponse) {
        tokenStore.save(
            token: response.token,
            userID: response.record.id,
            userName: response.record.name
        )
    }

    // MARK: - Records

    func listRecords<T: Decodable>(
        collection: String,
        filter: String? = nil,
        sort: String? = nil,
        expand: String? = nil,
        perPage: Int = 50
    ) async throws -> PBListResponse<T> {
        var query: [URLQueryItem] = [
            URLQueryItem(name: "perPage", value: String(perPage))
        ]
        if let filter { query.append(URLQueryItem(name: "filter", value: filter)) }
        if let sort { query.append(URLQueryItem(name: "sort", value: sort)) }
        if let expand { query.append(URLQueryItem(name: "expand", value: expand)) }

        return try await request(
            method: "GET",
            path: "/api/collections/\(collection)/records",
            query: query
        )
    }

    func getRecord<T: Decodable>(
        collection: String,
        id: String,
        expand: String? = nil
    ) async throws -> T {
        var query: [URLQueryItem] = []
        if let expand { query.append(URLQueryItem(name: "expand", value: expand)) }
        return try await request(
            method: "GET",
            path: "/api/collections/\(collection)/records/\(id)",
            query: query
        )
    }

    func createRecord<T: Decodable, B: Encodable>(
        collection: String,
        body: B
    ) async throws -> T {
        try await request(
            method: "POST",
            path: "/api/collections/\(collection)/records",
            body: body
        )
    }

    func updateRecord<T: Decodable, B: Encodable>(
        collection: String,
        id: String,
        body: B
    ) async throws -> T {
        try await request(
            method: "PATCH",
            path: "/api/collections/\(collection)/records/\(id)",
            body: body
        )
    }

    // MARK: - Transport

    private func request<T: Decodable>(
        method: String,
        path: String,
        query: [URLQueryItem] = [],
        body: (some Encodable)? = nil as String?,
        authenticated: Bool = true,
        overrideToken: String? = nil
    ) async throws -> T {
        guard var components = URLComponents(url: baseURL, resolvingAgainstBaseURL: false) else {
            throw PocketBaseError.invalidURL
        }
        components.path = path
        if !query.isEmpty { components.queryItems = query }
        guard let url = components.url else { throw PocketBaseError.invalidURL }

        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        if authenticated {
            guard let token = overrideToken ?? tokenStore.token else {
                throw PocketBaseError.unauthorized
            }
            request.setValue(token, forHTTPHeaderField: "Authorization")
        }

        if let body {
            request.httpBody = try encoder.encode(body)
        }

        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw PocketBaseError.missingData }

        guard (200 ... 299).contains(http.statusCode) else {
            let bodyText = String(data: data, encoding: .utf8) ?? ""
            if http.statusCode == 401 || http.statusCode == 403 {
                throw PocketBaseError.unauthorized
            }
            throw PocketBaseError.httpStatus(http.statusCode, bodyText)
        }

        do {
            return try decoder.decode(T.self, from: data)
        } catch {
            throw PocketBaseError.decoding(error)
        }
    }
}

// MARK: - Dates

enum PocketBaseDate {
    private static let formatters: [DateFormatter] = {
        let formats = [
            "yyyy-MM-dd HH:mm:ss.SSS'Z'",
            "yyyy-MM-dd HH:mm:ss'Z'",
            "yyyy-MM-dd'T'HH:mm:ss.SSS'Z'",
            "yyyy-MM-dd'T'HH:mm:ss'Z'",
            "yyyy-MM-dd"
        ]
        return formats.map { format in
            let f = DateFormatter()
            f.locale = Locale(identifier: "en_US_POSIX")
            f.timeZone = TimeZone(secondsFromGMT: 0)
            f.dateFormat = format
            return f
        }
    }()

    static func decode(from decoder: Decoder) throws -> Date {
        let container = try decoder.singleValueContainer()
        if let string = try? container.decode(String.self) {
            if string.isEmpty {
                throw DecodingError.dataCorruptedError(
                    in: container,
                    debugDescription: "empty date string"
                )
            }
            for formatter in formatters {
                if let date = formatter.date(from: string) { return date }
            }
            if let date = ISO8601DateFormatter().date(from: string) { return date }
        }
        throw DecodingError.dataCorruptedError(in: container, debugDescription: "无法解析日期")
    }

    /// PocketBase 空日期字段会返回 `""` 而不是 `null`，需单独处理。
    static func decodeIfPresent<K: CodingKey>(
        _ container: KeyedDecodingContainer<K>,
        forKey key: K
    ) throws -> Date? {
        guard container.contains(key) else { return nil }
        if try container.decodeNil(forKey: key) { return nil }
        if let string = try? container.decode(String.self, forKey: key), string.isEmpty {
            return nil
        }
        return try container.decode(Date.self, forKey: key)
    }

    static func encode(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss.SSS'Z'"
        return formatter.string(from: date)
    }

    static func todayBounds() -> (start: String, end: String) {
        let calendar = Calendar.current
        let start = calendar.startOfDay(for: Date())
        let end = calendar.date(byAdding: DateComponents(day: 1, second: -1), to: start) ?? Date()
        return (encode(start), encode(end))
    }
}
