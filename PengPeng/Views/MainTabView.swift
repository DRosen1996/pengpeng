import SwiftUI

struct MainTabView: View {
    @Environment(AppSession.self) private var session
    @Environment(ConversationStore.self) private var store
    @State private var selectedTab = 0

    var body: some View {
        TabView(selection: $selectedTab) {
            NearbyView(selectedTab: $selectedTab, api: session.api)
                .tabItem {
                    Label("附近", systemImage: "location")
                }
                .tag(0)

            MessagesView(selectedTab: $selectedTab)
                .tabItem {
                    Label("消息", systemImage: "bubble.left.and.bubble.right")
                }
                .badge(store.pendingBumpCount > 0 ? store.pendingBumpCount : 0)
                .tag(1)

            ProfileView(selectedTab: $selectedTab, api: session.api)
                .tabItem {
                    Label("我", systemImage: "person")
                }
                .tag(2)
        }
        .tint(AppTheme.accent)
    }
}

#Preview {
    let api = PengPengAPI()
    MainTabView()
        .environment(AppSession(api: api))
        .environment(ConversationStore(api: api))
}
