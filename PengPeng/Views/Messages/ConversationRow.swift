import SwiftUI

struct ConversationRow: View {
    let conversation: SportConversation
    var isExpired: Bool = false

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text(conversation.partner.name)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(isExpired ? AppTheme.tertiaryText : AppTheme.primaryText)
                    Spacer()
                    if let hours = conversation.remainingHours, !isExpired {
                        Text("还剩 \(hours)h")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(AppTheme.secondaryText)
                    } else if isExpired {
                        Text("已结束")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(AppTheme.tertiaryText)
                    }
                }

                Text("\(conversation.partner.sportLabel) · \(conversation.partner.durationMinutes) 分钟")
                    .font(.system(size: 13))
                    .foregroundStyle(AppTheme.secondaryText)

                if let topic = conversation.topic {
                    Text(topic.title)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(isExpired ? AppTheme.tertiaryText : AppTheme.primaryText)
                } else {
                    Text("待选话题")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(AppTheme.secondaryText)
                }

                Text(conversation.lastMessagePreview)
                    .font(.system(size: 13))
                    .foregroundStyle(AppTheme.tertiaryText)
                    .lineLimit(1)
            }
        }
        .padding(16)
        .background(isExpired ? AppTheme.chipBackground : AppTheme.surface)
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadius, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: AppTheme.cornerRadius, style: .continuous)
                .stroke(AppTheme.divider, lineWidth: 1)
        )
        .opacity(isExpired ? 0.75 : 1)
    }
}
