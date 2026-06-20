import SwiftUI

struct ConversationPreview: View {
    let messages: [TopicMessage]

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            ForEach(messages) { message in
                HStack {
                    if message.isMine { Spacer(minLength: 40) }
                    Text(bubbleText(for: message))
                        .font(.system(size: 14))
                        .foregroundStyle(message.isMine ? .white : AppTheme.primaryText)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                        .background(message.isMine ? AppTheme.bubbleMine : AppTheme.bubbleOther)
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    if !message.isMine { Spacer(minLength: 40) }
                }
            }
        }
    }

    private func bubbleText(for message: TopicMessage) -> String {
        let prefix = message.isMine ? "我" : message.senderName
        return "\(prefix)：\(message.text)"
    }
}
