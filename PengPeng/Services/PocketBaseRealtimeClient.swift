import Foundation

enum PBRealtimeAction: String, Decodable {
    case create
    case update
    case delete
}

private struct PBConnectPayload: Decodable {
    let clientId: String
}

private struct PBRealtimeRecordPayload<T: Decodable>: Decodable {
    let action: PBRealtimeAction
    let record: T
}

private struct PBRealtimeSubscribeBody: Encodable {
    let clientId: String
    let subscriptions: [String]
}

@MainActor
final class PocketBaseRealtimeClient {
    typealias MessageHandler = (PBRealtimeAction, PBMessageRecord) -> Void

    private let baseURL: URL
    private let tokenStore: TokenStore
    private let decoder: JSONDecoder
    private let sseSession: URLSession

    private var sseTask: Task<Void, Never>?
    private var clientId: String?
    private var activeSubscriptions: [String] = []
    private var messageHandler: MessageHandler?
    private var reconnectAttempt = 0
    private var shouldStayConnected = false

    private(set) var connectionState: String = "idle"

    init(
        baseURL: URL = APIConfig.baseURL,
        tokenStore: TokenStore = .shared
    ) {
        self.baseURL = baseURL
        self.tokenStore = tokenStore
        self.decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom(PocketBaseDate.decode)

        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 3_600
        config.timeoutIntervalForResource = 3_600
        config.waitsForConnectivity = false
        config.requestCachePolicy = .reloadIgnoringLocalCacheData
        config.urlCache = nil
        config.httpShouldUsePipelining = false
        config.httpAdditionalHeaders = [
            "Accept-Encoding": "identity",
            "Cache-Control": "no-cache",
        ]
        sseSession = URLSession(configuration: config)
    }

    func setMessageHandler(_ handler: MessageHandler?) {
        messageHandler = handler
    }

    func connectIfNeeded() {
        shouldStayConnected = true
        guard sseTask == nil else { return }
        startSSELoop()
    }

    func subscribe(topics: [String]) async throws {
        activeSubscriptions = topics
        RealtimeDebugLog.log("subscribe topics: \(topics.joined(separator: ", "))")
        connectIfNeeded()
        do {
            try await waitForConnection()
            try await postSubscriptions(topics)
            connectionState = "subscribed"
            RealtimeDebugLog.log("subscribe OK clientId=\(clientId ?? "?")")
        } catch {
            RealtimeDebugLog.log("subscribe abort: \(error.localizedDescription)")
            cancelSSETask()
            throw error
        }
    }

    func disconnect() {
        RealtimeDebugLog.log("disconnect")
        shouldStayConnected = false
        reconnectAttempt = 0
        activeSubscriptions = []
        clientId = nil
        connectionState = "idle"
        sseTask?.cancel()
        sseTask = nil
    }

    // MARK: - SSE

    private func startSSELoop() {
        sseTask?.cancel()
        sseTask = Task { [weak self] in
            guard let self else { return }
            await self.runSSEWithReconnect()
            self.sseTask = nil
        }
    }

    private func cancelSSETask() {
        sseTask?.cancel()
        sseTask = nil
        clientId = nil
        connectionState = "idle"
    }

    private func runSSEWithReconnect() async {
        while shouldStayConnected, !Task.isCancelled {
            do {
                connectionState = reconnectAttempt > 0 ? "reconnecting" : "connecting"
                RealtimeDebugLog.log("SSE \(connectionState)")
                try await openSSEStream()
                reconnectAttempt = 0
                connectionState = clientId == nil ? "connected" : "ready"
            } catch {
                if !shouldStayConnected || Task.isCancelled { break }
                if error is CancellationError { break }
                reconnectAttempt += 1
                let delay = min(pow(2.0, Double(reconnectAttempt)), 30)
                connectionState = "error"
                RealtimeDebugLog.log("SSE error: \(error.localizedDescription), retry in \(Int(delay))s")
                clientId = nil
                try? await Task.sleep(for: .seconds(delay))
            }
        }
        connectionState = "idle"
    }

    private func openSSEStream() async throws {
        guard let token = tokenStore.token else {
            throw PocketBaseError.unauthorized
        }

        var components = URLComponents(url: baseURL, resolvingAgainstBaseURL: false)
        components?.path = "/api/realtime"
        guard let url = components?.url else { throw PocketBaseError.invalidURL }

        var request = URLRequest(url: url)
        request.cachePolicy = .reloadIgnoringLocalCacheData
        request.timeoutInterval = 3_600
        request.setValue(token, forHTTPHeaderField: "Authorization")
        request.setValue("text/event-stream", forHTTPHeaderField: "Accept")
        request.setValue("identity", forHTTPHeaderField: "Accept-Encoding")
        request.setValue("no-cache", forHTTPHeaderField: "Cache-Control")
        request.setValue("keep-alive", forHTTPHeaderField: "Connection")

        RealtimeDebugLog.log("SSE opening \(url.absoluteString)")
        let (bytes, response) = try await sseSession.bytes(for: request)
        guard let http = response as? HTTPURLResponse else { throw PocketBaseError.missingData }

        let encoding = http.value(forHTTPHeaderField: "Content-Encoding") ?? "none"
        RealtimeDebugLog.log("SSE HTTP \(http.statusCode) encoding=\(encoding)")

        guard (200 ... 299).contains(http.statusCode) else {
            if http.statusCode == 401 || http.statusCode == 403 {
                throw PocketBaseError.unauthorized
            }
            throw PocketBaseError.httpStatus(http.statusCode, "Realtime SSE failed")
        }

        var eventName = ""
        var dataLines: [String] = []
        var lineBytes: [UInt8] = []

        for try await byte in bytes {
            try Task.checkCancellation()

            if byte == 10 {
                let line = String(bytes: lineBytes, encoding: .utf8)?
                    .trimmingCharacters(in: .whitespaces) ?? ""
                lineBytes = []

                if line.isEmpty {
                    if !eventName.isEmpty, !dataLines.isEmpty {
                        let payload = dataLines.joined(separator: "\n")
                        await handleSSEEvent(name: eventName, data: payload)
                    }
                    eventName = ""
                    dataLines = []
                } else if line.hasPrefix("event:") {
                    eventName = String(line.dropFirst(6)).trimmingCharacters(in: .whitespaces)
                } else if line.hasPrefix("data:") {
                    dataLines.append(String(line.dropFirst(5)).trimmingCharacters(in: .whitespaces))
                }
            } else if byte != 13 {
                lineBytes.append(byte)
            }
        }

        if !eventName.isEmpty, !dataLines.isEmpty {
            let payload = dataLines.joined(separator: "\n")
            await handleSSEEvent(name: eventName, data: payload)
        }

        RealtimeDebugLog.log("SSE stream ended")
    }

    private func handleSSEEvent(name: String, data: String) async {
        guard let jsonData = data.data(using: .utf8) else {
            RealtimeDebugLog.log("SSE invalid UTF-8 for event \(name)")
            return
        }

        if name == "PB_CONNECT" {
            do {
                let payload = try decoder.decode(PBConnectPayload.self, from: jsonData)
                clientId = payload.clientId
                connectionState = "ready"
                RealtimeDebugLog.log("PB_CONNECT clientId=\(payload.clientId)")
                if !activeSubscriptions.isEmpty {
                    try await postSubscriptions(activeSubscriptions)
                    RealtimeDebugLog.log("resubscribed \(activeSubscriptions.count) topic(s) after connect")
                }
            } catch {
                RealtimeDebugLog.log("PB_CONNECT decode failed: \(error)")
            }
            return
        }

        guard isMessageSubscriptionEvent(name) else {
            RealtimeDebugLog.log("ignored SSE event: \(name)")
            return
        }

        do {
            let payload = try decoder.decode(PBRealtimeRecordPayload<PBMessageRecord>.self, from: jsonData)
            RealtimeDebugLog.log("message \(payload.action.rawValue) id=\(payload.record.id)")
            messageHandler?(payload.action, payload.record)
        } catch {
            RealtimeDebugLog.log("message decode failed event=\(name) error=\(error)")
        }
    }

    /// PocketBase 用订阅 topic 作为 SSE `event` 名（如 `messages/*?filter=...`），不是 `PB_messages`。
    private func isMessageSubscriptionEvent(_ name: String) -> Bool {
        if activeSubscriptions.contains(name) { return true }
        if name == "PB_messages" { return true }
        return name.hasPrefix("messages/") || name == "messages"
    }

    // MARK: - Subscribe POST

    private func postSubscriptions(_ topics: [String]) async throws {
        guard let clientId else { throw PocketBaseError.missingData }
        guard let token = tokenStore.token else { throw PocketBaseError.unauthorized }

        var components = URLComponents(url: baseURL, resolvingAgainstBaseURL: false)
        components?.path = "/api/realtime"
        guard let url = components?.url else { throw PocketBaseError.invalidURL }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(token, forHTTPHeaderField: "Authorization")
        request.setValue("identity", forHTTPHeaderField: "Accept-Encoding")
        request.httpBody = try JSONEncoder().encode(
            PBRealtimeSubscribeBody(clientId: clientId, subscriptions: topics)
        )

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw PocketBaseError.missingData }
        guard (200 ... 299).contains(http.statusCode) else {
            let body = String(data: data, encoding: .utf8) ?? ""
            RealtimeDebugLog.log("subscribe POST failed \(http.statusCode): \(body)")
            throw PocketBaseError.httpStatus(http.statusCode, body)
        }
    }

    private func waitForConnection() async throws {
        if clientId != nil { return }
        for attempt in 0 ..< 150 {
            if clientId != nil { return }
            if sseTask == nil {
                RealtimeDebugLog.log("waitForConnection: SSE task missing, restarting")
                connectIfNeeded()
            }
            try await Task.sleep(for: .milliseconds(100))
            if attempt == 149 {
                RealtimeDebugLog.log("waitForConnection timeout (15s)")
            }
        }
        throw PocketBaseError.missingData
    }
}
