import Foundation

struct SportTopic: Identifiable, Hashable {
    let id: String
    let title: String
}

struct TopicMessage: Identifiable {
    let id: String
    let isMine: Bool
    let senderName: String
    let text: String
}
