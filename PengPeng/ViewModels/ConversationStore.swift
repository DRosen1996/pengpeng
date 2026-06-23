import Foundation
import Observation

@MainActor
@Observable
final class ConversationStore {
    private let api: PengPengAPI
    private let realtime = PocketBaseRealtimeClient()

    var pendingBumps: [PendingBump] = []
    var conversations: [SportConversation] = []
    var isLoading = false
    var lastError: String?
    var realtimeStatus: String = "idle"

    init(api: PengPengAPI) {
        self.api = api
        realtime.setMessageHandler { [weak self] action, record in
            self?.handleMessageEvent(action: action, record: record)
        }
        if !api.isAuthenticated {
            loadMockData()
        }
    }

    convenience init() {
        self.init(api: PengPengAPI())
    }

    private func loadMockData() {
        pendingBumps = MockData.pendingBumps
        conversations = MockData.conversations
    }

    var pendingBumpCount: Int {
        pendingBumps.filter { $0.status == .pending }.count
    }

    var activeConversations: [SportConversation] {
        conversations.filter { $0.phase == .active || $0.phase == .awaitingTopic }
            .sorted { $0.startedAt > $1.startedAt }
    }

    var expiredConversations: [SportConversation] {
        conversations.filter { $0.phase == .expired }
            .sorted { $0.startedAt > $1.startedAt }
    }

    var pendingBumpsList: [PendingBump] {
        pendingBumps.filter { $0.status == .pending }
            .sorted { $0.receivedAt > $1.receivedAt }
    }

    func refresh() async {
        guard api.isAuthenticated else { return }
        isLoading = true
        defer { isLoading = false }

        do {
            async let bumps = api.fetchPendingBumps()
            async let convs = api.fetchConversations()
            pendingBumps = try await bumps
            conversations = try await convs
            lastError = nil
        } catch {
            lastError = error.localizedDescription
        }
    }

    func reset() {
        stopRealtime()
        pendingBumps = []
        conversations = []
        lastError = nil
        if !api.isAuthenticated {
            loadMockData()
        }
    }

    func stopRealtime() {
        realtime.disconnect()
        realtimeStatus = "idle"
    }

    var realtimeDebugSummary: String {
        RealtimeDebugLog.recentSummary
    }

    func subscribeMessages(conversationID: String) async {
        guard api.isAuthenticated else { return }
        let topic = "messages/*?filter=conversation='\(conversationID)'"
        RealtimeDebugLog.log("ConversationStore subscribe \(conversationID)")
        do {
            try await realtime.subscribe(topics: [topic])
            realtimeStatus = realtime.connectionState
            lastError = nil
        } catch {
            realtimeStatus = "error"
            lastError = error.localizedDescription
            RealtimeDebugLog.log("subscribe failed: \(error.localizedDescription)")
        }
    }

    func unsubscribeMessages(conversationID: String) {
        stopRealtime()
    }

    @discardableResult
    func sendBumpFromNearby(partner: NearbyUser, topic: SportTopic) async -> Bool {
        guard api.isAuthenticated else {
            _ = legacyCreateConversation(partner: partner, topic: topic)
            return true
        }

        do {
            let message = "想聊聊：\(topic.title)"
            _ = try await api.sendBump(to: partner.id, message: message)
            lastError = nil
            return true
        } catch {
            lastError = error.localizedDescription
            return false
        }
    }

    func conversation(for id: String) -> SportConversation? {
        conversations.first { $0.id == id }
    }

    func conversation(forPartner partnerID: String) -> SportConversation? {
        conversations.first { $0.partner.id == partnerID && $0.phase != .expired }
    }

    @discardableResult
    func acceptBump(id: String) async -> SportConversation? {
        guard api.isAuthenticated else {
            return legacyAcceptBump(id: id)
        }

        guard let index = pendingBumps.firstIndex(where: { $0.id == id && $0.status == .pending }) else {
            return nil
        }

        let bump = pendingBumps[index]

        do {
            _ = try await api.acceptBump(id: id)
            pendingBumps[index].status = .accepted

            if let existing = conversation(forPartner: bump.fromUser.id) {
                return existing
            }

            let record = try await api.createConversation(
                partnerID: bump.fromUser.id,
                topic: nil,
                phase: .awaitingTopic
            )
            await refresh()
            return conversation(for: record.id) ?? conversation(forPartner: bump.fromUser.id)
        } catch {
            lastError = error.localizedDescription
            return nil
        }
    }

    func dismissBump(id: String) async {
        guard api.isAuthenticated else {
            legacyDismissBump(id: id)
            return
        }

        guard let index = pendingBumps.firstIndex(where: { $0.id == id }) else { return }

        do {
            _ = try await api.dismissBump(id: id)
            pendingBumps[index].status = .dismissed
        } catch {
            lastError = error.localizedDescription
        }
    }

    @discardableResult
    func createConversationFromNearby(partner: NearbyUser, topic: SportTopic) async -> SportConversation? {
        guard api.isAuthenticated else {
            return legacyCreateConversation(partner: partner, topic: topic)
        }

        do {
            if let existing = try await api.findConversation(with: partner.id) {
                _ = try await api.activateConversation(id: existing.id, topic: topic)
                try await api.seedTopicMessages(conversationID: existing.id, topic: topic, partnerName: partner.name)
            } else {
                let record = try await api.createConversation(
                    partnerID: partner.id,
                    topic: topic,
                    phase: .active
                )
                try await api.seedTopicMessages(conversationID: record.id, topic: topic, partnerName: partner.name)
            }
            await refresh()
            return conversation(forPartner: partner.id)
        } catch {
            lastError = error.localizedDescription
            return legacyCreateConversation(partner: partner, topic: topic)
        }
    }

    func selectTopic(conversationID: String, topic: SportTopic) async {
        guard api.isAuthenticated else {
            legacySelectTopic(conversationID: conversationID, topic: topic)
            return
        }

        do {
            _ = try await api.activateConversation(id: conversationID, topic: topic)
            try await api.seedTopicMessages(conversationID: conversationID, topic: topic, partnerName: "")
            let expiresAt = Date().addingTimeInterval(24 * 3600)
            updateConversation(id: conversationID) { conversation in
                conversation.topic = topic
                conversation.phase = .active
                conversation.expiresAt = expiresAt
            }
            await refreshMessages(conversationID: conversationID)
        } catch {
            lastError = error.localizedDescription
        }
    }

    func sendMessage(conversationID: String, text: String) async {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty,
              let index = conversations.firstIndex(where: { $0.id == conversationID }),
              conversations[index].phase == .active
        else { return }

        guard api.isAuthenticated else {
            legacySendMessage(conversationID: conversationID, text: trimmed)
            return
        }

        let pendingID = "pending-\(UUID().uuidString)"
        let optimistic = TopicMessage(id: pendingID, isMine: true, senderName: "我", text: trimmed)
        updateConversation(id: conversationID) { $0.messages.append(optimistic) }

        do {
            let record = try await api.sendMessage(conversationID: conversationID, text: trimmed)
            applySentMessage(record, conversationID: conversationID, pendingID: pendingID)
            lastError = nil
        } catch {
            updateConversation(id: conversationID) { conversation in
                conversation.messages.removeAll { $0.id == pendingID }
            }
            lastError = error.localizedDescription
        }
    }

    func refreshMessages(conversationID: String) async {
        guard conversations.contains(where: { $0.id == conversationID }) else { return }
        do {
            let messages = try await api.fetchMessages(conversationID: conversationID)
            updateConversation(id: conversationID) { $0.messages = messages }
            lastError = nil
        } catch {
            lastError = error.localizedDescription
        }
    }

    private func updateConversation(
        id: String,
        _ transform: (inout SportConversation) -> Void
    ) {
        guard let index = conversations.firstIndex(where: { $0.id == id }) else { return }
        var updated = conversations[index]
        transform(&updated)
        conversations[index] = updated
    }

    private func applySentMessage(_ record: PBMessageRecord, conversationID: String, pendingID: String) {
        guard let userID = api.currentUserID,
              let message = PBMapping.topicMessage(
                  from: record,
                  currentUserID: userID,
                  currentUserName: api.currentUserName ?? "我"
              )
        else { return }

        updateConversation(id: conversationID) { conversation in
            if let pendingIndex = conversation.messages.firstIndex(where: { $0.id == pendingID }) {
                conversation.messages[pendingIndex] = message
            } else if !conversation.messages.contains(where: { $0.id == message.id }) {
                conversation.messages.append(message)
            }

            conversation.messages.removeAll {
                $0.id.hasPrefix("pending-") && $0.id != message.id && $0.text == message.text && $0.isMine
            }
        }
    }

    private func handleMessageEvent(action: PBRealtimeAction, record: PBMessageRecord) {
        realtimeStatus = "event:\(action.rawValue)"

        guard action == .create else {
            RealtimeDebugLog.log("skip non-create action \(action.rawValue)")
            return
        }

        guard let userID = api.currentUserID else {
            RealtimeDebugLog.log("skip message: no current user")
            return
        }

        guard let message = PBMapping.topicMessage(
            from: record,
            currentUserID: userID,
            currentUserName: api.currentUserName ?? "我"
        ) else {
            RealtimeDebugLog.log("skip message: mapping failed id=\(record.id)")
            return
        }

        let conversationID = record.conversation.id
        guard let conversationID else {
            RealtimeDebugLog.log("skip message: no conversation id record=\(record.id)")
            return
        }

        guard conversations.contains(where: { $0.id == conversationID }) else {
            RealtimeDebugLog.log("skip message: conversation \(conversationID) not in store")
            return
        }

        updateConversation(id: conversationID) { conversation in
            if message.isMine {
                conversation.messages.removeAll {
                    $0.id.hasPrefix("pending-") && $0.text == message.text && $0.isMine
                }
            }

            guard !conversation.messages.contains(where: { $0.id == message.id }) else {
                RealtimeDebugLog.log("skip duplicate message \(message.id)")
                return
            }
            conversation.messages.append(message)
            RealtimeDebugLog.log("appended message \(message.id) conv=\(conversationID) count=\(conversation.messages.count)")
        }
    }

    // MARK: - Mock fallbacks (previews / offline)

    @discardableResult
    private func legacyAcceptBump(id: String) -> SportConversation? {
        guard let index = pendingBumps.firstIndex(where: { $0.id == id && $0.status == .pending }) else {
            return nil
        }
        let bump = pendingBumps[index]
        pendingBumps[index].status = .accepted
        if let existing = conversation(forPartner: bump.fromUser.id) { return existing }
        let conversation = SportConversation(
            id: "conv-\(bump.fromUser.id)",
            partner: bump.fromUser,
            topic: nil,
            messages: [],
            startedAt: Date(),
            expiresAt: nil,
            phase: .awaitingTopic
        )
        conversations.append(conversation)
        return conversation
    }

    private func legacyDismissBump(id: String) {
        guard let index = pendingBumps.firstIndex(where: { $0.id == id }) else { return }
        pendingBumps[index].status = .dismissed
    }

    @discardableResult
    private func legacyCreateConversation(partner: NearbyUser, topic: SportTopic) -> SportConversation {
        if let index = conversations.firstIndex(where: { $0.partner.id == partner.id }) {
            legacySelectTopic(conversationID: conversations[index].id, topic: topic)
            return conversations[index]
        }
        let messages = MockData.topicConversation(for: topic, partner: partner)
        let now = Date()
        let conversation = SportConversation(
            id: "conv-\(partner.id)",
            partner: partner,
            topic: topic,
            messages: messages,
            startedAt: now,
            expiresAt: now.addingTimeInterval(24 * 3600),
            phase: .active
        )
        conversations.append(conversation)
        return conversation
    }

    private func legacySelectTopic(conversationID: String, topic: SportTopic) {
        guard let index = conversations.firstIndex(where: { $0.id == conversationID }) else { return }
        let partner = conversations[index].partner
        let messages = MockData.topicConversation(for: topic, partner: partner)
        let now = Date()
        var updated = conversations[index]
        updated.topic = topic
        updated.messages = messages
        updated.expiresAt = now.addingTimeInterval(24 * 3600)
        updated.phase = .active
        conversations[index] = updated
    }

    private func legacySendMessage(conversationID: String, text: String) {
        guard let index = conversations.firstIndex(where: { $0.id == conversationID }),
              conversations[index].phase == .active
        else { return }
        let message = TopicMessage(id: UUID().uuidString, isMine: true, senderName: "我", text: text)
        updateConversation(id: conversationID) { $0.messages.append(message) }
    }
}
