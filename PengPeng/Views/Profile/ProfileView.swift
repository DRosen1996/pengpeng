import SwiftUI

struct ProfileView: View {
    @Environment(AppSession.self) private var session
    @Environment(ConversationStore.self) private var store
    @Binding var selectedTab: Int
    @State private var viewModel: ProfileViewModel

    init(selectedTab: Binding<Int>, api: PengPengAPI) {
        _selectedTab = selectedTab
        _viewModel = State(initialValue: ProfileViewModel(api: api))
    }

    var body: some View {
        @Bindable var viewModel = viewModel

        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    ProfileHeaderCard(
                        userName: viewModel.userName,
                        weeklyWorkouts: viewModel.weeklyWorkouts,
                        todayBumps: store.pendingBumpCount + store.activeConversations.count,
                        activityRingPercent: viewModel.activityRingPercent
                    )
                    TodayWorkoutSection(
                        workout: viewModel.todayWorkout,
                        hasPublishedPresence: viewModel.hasTodayPresence,
                        isSyncing: viewModel.isSyncingPresence,
                        onSync: session.isAuthenticated ? {
                            Task { await viewModel.syncTodayPresence() }
                        } : nil
                    )
                    SportCardSection(tags: viewModel.tags)
                    ReceivedBumpsSection(bumps: store.pendingBumpsList) {
                        selectedTab = 1
                    }

                    if session.isAuthenticated {
                        Button("退出登录") {
                            store.reset()
                            session.logout()
                        }
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(.red)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                    }

                    if let error = viewModel.lastError {
                        Text(error)
                            .font(.system(size: 13))
                            .foregroundStyle(.red)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                .padding(16)
            }
            .background(AppTheme.background)
            .navigationTitle("我")
            .navigationBarTitleDisplayMode(.large)
            .refreshable {
                await viewModel.load()
                await store.refresh()
            }
            .task {
                await viewModel.load()
            }
        }
    }
}

#Preview {
    ProfileView(selectedTab: .constant(2), api: PengPengAPI())
        .environment(AppSession())
        .environment(ConversationStore())
}
