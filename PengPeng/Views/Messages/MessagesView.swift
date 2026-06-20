import SwiftUI

struct MessagesView: View {
    @Environment(ConversationStore.self) private var store
    @Binding var selectedTab: Int

    @State private var navigationPath = NavigationPath()

    var body: some View {
        NavigationStack(path: $navigationPath) {
            Group {
                if isEmpty {
                    emptyState
                } else {
                    inboxList
                }
            }
            .background(AppTheme.background)
            .navigationTitle("消息")
            .navigationBarTitleDisplayMode(.large)
            .navigationDestination(for: String.self) { conversationID in
                ConversationDetailView(conversationID: conversationID)
            }
            .refreshable {
                await store.refresh()
            }
            .task {
                await store.refresh()
            }
        }
    }

    private var isEmpty: Bool {
        store.pendingBumpsList.isEmpty && store.conversations.isEmpty
    }

    private var inboxList: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                if store.pendingBumpCount > 0 {
                    pendingBanner
                }

                if !store.pendingBumpsList.isEmpty {
                    sectionHeader("待处理")
                    ForEach(store.pendingBumpsList) { bump in
                        PendingBumpRow(
                            bump: bump,
                            onAccept: {
                                Task {
                                    if let conversation = await store.acceptBump(id: bump.id) {
                                        navigationPath.append(conversation.id)
                                    }
                                }
                            },
                            onDismiss: {
                                Task { await store.dismissBump(id: bump.id) }
                            }
                        )
                    }
                }

                if !store.activeConversations.isEmpty {
                    sectionHeader("进行中")
                    ForEach(store.activeConversations) { conversation in
                        NavigationLink(value: conversation.id) {
                            ConversationRow(conversation: conversation)
                        }
                        .buttonStyle(.plain)
                    }
                }

                if !store.expiredConversations.isEmpty {
                    sectionHeader("已结束")
                    ForEach(store.expiredConversations) { conversation in
                        NavigationLink(value: conversation.id) {
                            ConversationRow(conversation: conversation, isExpired: true)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .padding(16)
        }
    }

    private var pendingBanner: some View {
        Text("你有 \(store.pendingBumpCount) 个碰碰待处理")
            .font(.system(size: 13, weight: .medium))
            .foregroundStyle(AppTheme.primaryText)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(AppTheme.chipBackground)
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(AppTheme.tertiaryText)
            .textCase(.uppercase)
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: "bubble.left.and.bubble.right")
                .font(.system(size: 48))
                .foregroundStyle(AppTheme.tertiaryText)
            Text("还没有运动话题")
                .font(.system(size: 18, weight: .semibold))
            Text("在附近碰碰同项目运动者，开启 24 小时话题")
                .font(.system(size: 14))
                .foregroundStyle(AppTheme.secondaryText)
                .multilineTextAlignment(.center)
            PrimaryButton(title: "去附近碰碰") {
                selectedTab = 0
            }
            .padding(.horizontal, 40)
            Spacer()
        }
        .padding(24)
    }
}

#Preview {
    MessagesView(selectedTab: .constant(1))
        .environment(ConversationStore())
}
