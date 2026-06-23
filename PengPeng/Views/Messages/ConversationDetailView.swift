import SwiftUI

struct ConversationDetailView: View {
    @Environment(ConversationStore.self) private var store

    let conversationID: String
    @State private var draftText = ""
    @State private var selectedTopic: SportTopic?

    private var conversation: SportConversation? {
        store.conversation(for: conversationID)
    }

    private var messages: [TopicMessage] {
        store.conversation(for: conversationID)?.messages ?? []
    }

    var body: some View {
        Group {
            if let conversation {
                detailContent(for: conversation)
            } else {
                ContentUnavailableView("会话不存在", systemImage: "bubble.left.and.bubble.right")
            }
        }
        .background(AppTheme.background)
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            selectedTopic = conversation?.topic
        }
        .task(id: conversationID) {
            await store.refreshMessages(conversationID: conversationID)
            await store.subscribeMessages(conversationID: conversationID)
        }
        .onDisappear {
            store.unsubscribeMessages(conversationID: conversationID)
        }
    }

    @ViewBuilder
    private func detailContent(for conversation: SportConversation) -> some View {
        VStack(spacing: 0) {
            header(for: conversation)
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        if conversation.phase == .awaitingTopic {
                            topicSelectionSection
                        } else {
                            MessageBubbleList(messages: messages)
                                .id("messages")
                        }
                    }
                    .padding(16)
                }
                .onChange(of: messages.count) { _, _ in
                    withAnimation {
                        proxy.scrollTo("messages", anchor: .bottom)
                    }
                }
            }

            if conversation.phase == .active {
                MessageComposer(text: $draftText, isEnabled: true) {
                    let text = draftText
                    draftText = ""
                    Task { await store.sendMessage(conversationID: conversationID, text: text) }
                }
            } else if conversation.phase == .expired {
                MessageComposer(text: $draftText, isEnabled: false) {}
            }
        }
        .navigationTitle(conversation.partner.name)
    }

    private func header(for conversation: SportConversation) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("你和 \(conversation.partner.name) 今天都完成了\(conversation.partner.sportLabel)")
                .font(.system(size: 13))
                .foregroundStyle(AppTheme.secondaryText)

            switch conversation.phase {
            case .awaitingTopic:
                Text("先选一个运动话题，24 小时有效")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(AppTheme.primaryText)
            case .active:
                HStack {
                    if let topic = conversation.topic {
                        Text(topic.title)
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(AppTheme.primaryText)
                    }
                    Spacer()
                    if let hours = conversation.remainingHours {
                        Text("还剩 \(hours) 小时")
                            .font(.system(size: 12))
                            .foregroundStyle(AppTheme.secondaryText)
                    }
                }
            case .expired:
                Text("话题已结束")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(AppTheme.tertiaryText)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(AppTheme.surface)
        .overlay(alignment: .bottom) {
            Divider()
        }
    }

    private var topicSelectionSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("选择话题")
                .font(.system(size: 15, weight: .semibold))
            TopicPicker(
                topics: MockData.sportTopics,
                selectedTopic: $selectedTopic
            ) { topic in
                Task { await store.selectTopic(conversationID: conversationID, topic: topic) }
            }
        }
    }
}
