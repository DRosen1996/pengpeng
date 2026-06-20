import Foundation

enum ConversationPhase: String, Hashable {
    case awaitingTopic
    case active
    case expired
}

struct SportConversation: Identifiable {
    let id: String
    let partner: NearbyUser
    var topic: SportTopic?
    var messages: [TopicMessage]
    let startedAt: Date
    var expiresAt: Date?
    var phase: ConversationPhase

    var lastMessagePreview: String {
        messages.last?.text ?? topic?.title ?? "待选话题"
    }

    var remainingHours: Int? {
        guard let expiresAt, phase == .active else { return nil }
        let hours = Int(expiresAt.timeIntervalSinceNow / 3600)
        return max(0, hours)
    }
}
