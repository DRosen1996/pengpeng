import SwiftUI

@main
struct PengPengApp: App {
    @State private var session = AppSession()
    @State private var store: ConversationStore

    init() {
        let api = PengPengAPI()
        _session = State(initialValue: AppSession(api: api))
        _store = State(initialValue: ConversationStore(api: api))
    }

    var body: some Scene {
        WindowGroup {
            Group {
                if session.isAuthenticated {
                    MainTabView()
                        .environment(store)
                        .environment(session)
                        .task {
                            await store.refresh()
                        }
                } else {
                    LoginView(session: session)
                }
            }
            .preferredColorScheme(.light)
        }
    }
}
