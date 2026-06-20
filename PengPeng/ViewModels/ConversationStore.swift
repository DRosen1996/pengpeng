import Foundation
import Observation

@MainActor
@Observable
final class ConversationStore {
    private let api: PengPengAPI

    var pendingBumps: [PendingBump] = []
    var conversations: [SportConversation] = []
    var isLoading = false
    var lastError: String?

    init(api: PengPengAPI) {
        self.api = api
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
        pendingBumps = []
        conversations = []
        lastError = nil
        if !api.isAuthenticated {
            loadMockData()
        }
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

        do {
            _ = try await api.sendMessage(conversationID: conversationID, text: trimmed)
            await refreshMessages(conversationID: conversationID)
        } catch {
            lastError = error.localizedDescription
        }
    }

    private func refreshMessages(conversationID: String) async {
        guard let index = conversations.firstIndex(where: { $0.id == conversationID }) else { return }
        do {
            conversations[index].messages = try await api.fetchMessages(conversationID: conversationID)
        } catch {
            lastError = error.localizedDescription
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
        conversations[index].topic = topic
        conversations[index].messages = messages
        conversations[index].expiresAt = now.addingTimeInterval(24 * 3600)
        conversations[index].phase = .active
    }

    private func legacySendMessage(conversationID: String, text: String) {
        guard let index = conversations.firstIndex(where: { $0.id == conversationID }),
              conversations[index].phase == .active
        else { return }
        let message = TopicMessage(id: UUID().uuidString, isMine: true, senderName: "我", text: text)
        conversations[index].messages.append(message)
    }
}
