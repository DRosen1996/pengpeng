import SwiftUI

struct MainTabView: View {
    @Environment(AppSession.self) private var session
    @Environment(ConversationStore.self) private var store
    @State private var selectedTab = 0
    @State private var nearbyViewModel: NearbyViewModel?

    var body: some View {
        TabView(selection: $selectedTab) {
            Group {
                if let nearbyViewModel {
                    NearbyView(selectedTab: $selectedTab, viewModel: nearbyViewModel)
                } else {
                    ProgressView()
                }
            }
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
        .onAppear {
            if nearbyViewModel == nil {
                nearbyViewModel = NearbyViewModel(
                    api: session.api,
                    workoutStore: session.workoutStore
                )
            }
        }
    }
}

#Preview {
    let api = PengPengAPI()
    MainTabView()
        .environment(AppSession(api: api))
        .environment(ConversationStore(api: api))
}
