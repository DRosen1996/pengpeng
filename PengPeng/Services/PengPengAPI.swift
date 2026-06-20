import Foundation

final class PengPengAPI {
    let client: PocketBaseClient

    init(client: PocketBaseClient = PocketBaseClient()) {
        self.client = client
    }

    var isAuthenticated: Bool { TokenStore.shared.isAuthenticated }
    var currentUserID: String? { client.currentUserID }
    var currentUserName: String? { TokenStore.shared.userName }

    // MARK: - Auth

    func login(email: String, password: String) async throws {
        _ = try await client.authWithPassword(identity: email, password: password)
    }

    func logout() {
        client.logout()
    }

    // MARK: - User

    func fetchCurrentUser() async throws -> PBUserRecord {
        guard let userID = currentUserID else { throw PocketBaseError.unauthorized }
        return try await client.getRecord(
            collection: APIConfig.usersCollection,
            id: userID
        )
    }

    func updateCurrentUser(
        name: String? = nil,
        tags: [String]? = nil,
        geohash: String? = nil
    ) async throws -> PBUserRecord {
        guard let userID = currentUserID else { throw PocketBaseError.unauthorized }
        let patch = PBUserPatch(
            name: name,
            tags: tags,
            geohash: geohash,
            geohashUpdatedAt: geohash.map { _ in PocketBaseDate.encode(Date()) }
        )
        return try await client.updateRecord(
            collection: APIConfig.usersCollection,
            id: userID,
            body: patch
        )
    }

    // MARK: - Presence

    func fetchTodayPresences(geohashPrefix: String = APIConfig.defaultGeohashPrefix) async throws -> [PBPresenceRecord] {
        let bounds = PocketBaseDate.todayBounds()
        let filter = "geohash~'\(geohashPrefix)' && date>='\(bounds.start)' && date<='\(bounds.end)'"
        let response: PBListResponse<PBPresenceRecord> = try await client.listRecords(
            collection: APIConfig.presenceCollection,
            filter: filter,
            expand: "user"
        )
        return response.items
    }

    func fetchMyTodayPresence() async throws -> PBPresenceRecord? {
        guard let userID = currentUserID else { throw PocketBaseError.unauthorized }
        let bounds = PocketBaseDate.todayBounds()
        let filter = "user='\(userID)' && date>='\(bounds.start)' && date<='\(bounds.end)'"
        let response: PBListResponse<PBPresenceRecord> = try await client.listRecords(
            collection: APIConfig.presenceCollection,
            filter: filter
        )
        return response.items.first
    }

    func upsertTodayPresence(
        sport: SportType,
        durationMinutes: Int,
        energyKcal: Int,
        geohash: String = APIConfig.defaultGeohashPrefix,
        streakLabel: String? = nil,
        focusLabel: String? = nil
    ) async throws -> PBPresenceRecord {
        guard let userID = currentUserID else { throw PocketBaseError.unauthorized }

        let bounds = PocketBaseDate.todayBounds()
        let body = PBPresenceBody(
            user: userID,
            sport: sport.rawValue,
            durationMinutes: durationMinutes,
            energyKcal: energyKcal,
            geohash: geohash,
            date: bounds.start,
            streakLabel: streakLabel,
            focusLabel: focusLabel
        )

        let record: PBPresenceRecord
        if let existing = try await fetchMyTodayPresence() {
            record = try await client.updateRecord(
                collection: APIConfig.presenceCollection,
                id: existing.id,
                body: body
            )
        } else {
            record = try await client.createRecord(
                collection: APIConfig.presenceCollection,
                body: body
            )
        }

        _ = try await updateCurrentUser(geohash: geohash)
        return record
    }

    func fetchNearbyUsers(
        sport: SportType,
        geohashPrefix: String = APIConfig.defaultGeohashPrefix
    ) async throws -> [NearbyUser] {
        let bounds = PocketBaseDate.todayBounds()
        let filter = """
        sport='\(sport.rawValue)' && geohash~'\(geohashPrefix)' && \
        date>='\(bounds.start)' && date<='\(bounds.end)'
        """
        let response: PBListResponse<PBPresenceRecord> = try await client.listRecords(
            collection: APIConfig.presenceCollection,
            filter: filter,
            expand: "user"
        )
        return response.items.compactMap {
            PBMapping.nearbyUser(from: $0, excludingUserID: currentUserID)
        }
    }

    // MARK: - Bumps

    func fetchPendingBumps() async throws -> [PendingBump] {
        guard let userID = currentUserID else { throw PocketBaseError.unauthorized }
        let filter = "to_user='\(userID)' && status='pending'"
        let response: PBListResponse<PBBumpRecord> = try await client.listRecords(
            collection: APIConfig.bumpsCollection,
            filter: filter,
            sort: "-created",
            expand: "from_user"
        )

        let presences = try await fetchTodayPresences()
        let presenceMap = Dictionary(
            presences.compactMap { record -> (String, PBPresenceRecord)? in
                guard let id = record.user.id ?? record.user.expandedValue?.id else { return nil }
                return (id, record)
            },
            uniquingKeysWith: { first, _ in first }
        )

        return response.items.compactMap {
            PBMapping.pendingBump(from: $0, presenceByUserID: presenceMap)
        }
    }

    func sendBump(to userID: String, message: String) async throws -> PBBumpRecord {
        guard let fromID = currentUserID else { throw PocketBaseError.unauthorized }
        let body = PBBumpBody(
            fromUser: fromID,
            toUser: userID,
            message: message,
            status: BumpStatus.pending.rawValue
        )
        return try await client.createRecord(
            collection: APIConfig.bumpsCollection,
            body: body
        )
    }

    func acceptBump(id: String) async throws -> PBBumpRecord {
        try await client.updateRecord(
            collection: APIConfig.bumpsCollection,
            id: id,
            body: PBBumpPatch(status: BumpStatus.accepted.rawValue)
        )
    }

    func dismissBump(id: String) async throws -> PBBumpRecord {
        try await client.updateRecord(
            collection: APIConfig.bumpsCollection,
            id: id,
            body: PBBumpPatch(status: BumpStatus.dismissed.rawValue)
        )
    }

    // MARK: - Conversations

    func fetchConversations() async throws -> [SportConversation] {
        guard let userID = currentUserID else { throw PocketBaseError.unauthorized }
        let filter = "user_a='\(userID)' || user_b='\(userID)'"
        let response: PBListResponse<PBConversationRecord> = try await client.listRecords(
            collection: APIConfig.conversationsCollection,
            filter: filter,
            sort: "-started_at",
            expand: "user_a,user_b"
        )

        var result: [SportConversation] = []
        for record in response.items {
            let messages = try await fetchMessages(conversationID: record.id)
            if let conversation = PBMapping.conversation(
                from: record,
                messages: messages,
                currentUserID: userID
            ) {
                result.append(conversation)
            }
        }
        return result
    }

    func createConversation(
        partnerID: String,
        topic: SportTopic?,
        phase: ConversationPhase = .awaitingTopic
    ) async throws -> PBConversationRecord {
        guard let userID = currentUserID else { throw PocketBaseError.unauthorized }
        let now = Date()
        let expires = phase == .active ? now.addingTimeInterval(24 * 3600) : nil
        let body = PBConversationBody(
            userA: userID,
            userB: partnerID,
            topicID: topic?.id,
            phase: phase.rawValue,
            startedAt: PocketBaseDate.encode(now),
            expiresAt: expires.map { PocketBaseDate.encode($0) }
        )
        return try await client.createRecord(
            collection: APIConfig.conversationsCollection,
            body: body
        )
    }

    func activateConversation(id: String, topic: SportTopic) async throws -> PBConversationRecord {
        let expires = Date().addingTimeInterval(24 * 3600)
        let patch = PBConversationPatch(
            topicID: topic.id,
            phase: ConversationPhase.active.rawValue,
            expiresAt: PocketBaseDate.encode(expires)
        )
        return try await client.updateRecord(
            collection: APIConfig.conversationsCollection,
            id: id,
            body: patch
        )
    }

    func findConversation(with partnerID: String) async throws -> PBConversationRecord? {
        guard let userID = currentUserID else { throw PocketBaseError.unauthorized }
        let filter = """
        (user_a='\(userID)' && user_b='\(partnerID)') || \
        (user_a='\(partnerID)' && user_b='\(userID)')
        """
        let response: PBListResponse<PBConversationRecord> = try await client.listRecords(
            collection: APIConfig.conversationsCollection,
            filter: filter,
            sort: "-created",
            perPage: 1
        )
        return response.items.first
    }

    // MARK: - Messages

    func fetchMessages(conversationID: String) async throws -> [TopicMessage] {
        guard let userID = currentUserID else { throw PocketBaseError.unauthorized }
        let filter = "conversation='\(conversationID)'"
        let response: PBListResponse<PBMessageRecord> = try await client.listRecords(
            collection: APIConfig.messagesCollection,
            filter: filter,
            sort: "created",
            expand: "sender"
        )
        return response.items.compactMap {
            PBMapping.topicMessage(
                from: $0,
                currentUserID: userID,
                currentUserName: currentUserName ?? "我"
            )
        }
    }

    func sendMessage(conversationID: String, text: String) async throws -> PBMessageRecord {
        guard let userID = currentUserID else { throw PocketBaseError.unauthorized }
        let body = PBMessageBody(
            conversation: conversationID,
            sender: userID,
            text: text
        )
        return try await client.createRecord(
            collection: APIConfig.messagesCollection,
            body: body
        )
    }

    func seedTopicMessages(conversationID: String, topic: SportTopic, partnerName: String) async throws {
        guard let userID = currentUserID else { throw PocketBaseError.unauthorized }
        let _: PBMessageRecord = try await client.createRecord(
            collection: APIConfig.messagesCollection,
            body: PBMessageBody(conversation: conversationID, sender: userID, text: topic.title)
        )
    }
}
