import SwiftUI

struct SportTopicView: View {
    let partner: NearbyUser
    let topics: [SportTopic]
    @Binding var selectedTopic: SportTopic?
    var bumpSent: Bool = false
    let conversation: (SportTopic) -> [TopicMessage]
    let onTopicSelect: (SportTopic) -> Void

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    introSection
                    TopicPicker(
                        topics: topics,
                        selectedTopic: $selectedTopic,
                        onSelect: onTopicSelect
                    )
                    if let topic = selectedTopic {
                        conversationSection(for: topic)
                        savedHint
                    }
                }
                .padding(20)
            }
            .background(AppTheme.background)
            .navigationTitle("运动话题")
            .navigationBarTitleDisplayMode(.inline)
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
    }

    private var introSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("碰上了")
                .font(.system(size: 18, weight: .semibold))
            Text("你和 \(partner.name) 今天都完成了\(partner.sportLabel)。从运动开始聊，24 小时有效。")
                .font(.system(size: 14))
                .foregroundStyle(AppTheme.secondaryText)
        }
    }

    private func conversationSection(for topic: SportTopic) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("轻对话预览")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(AppTheme.tertiaryText)
            ConversationPreview(messages: conversation(topic))
        }
        .padding(.top, 8)
    }

    private var savedHint: some View {
        HStack(spacing: 8) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(AppTheme.accent)
            Text(bumpSent ? "碰碰已发送，等对方在消息里回应" : "选择话题后将发送碰碰")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(AppTheme.secondaryText)
        }
        .padding(.top, 4)
    }
}
