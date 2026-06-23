import SwiftUI

struct ProfileView: View {
    @Environment(AppSession.self) private var session
    @Environment(ConversationStore.self) private var store
    @Binding var selectedTab: Int
    @State private var viewModel: ProfileViewModel
    @State private var developerTapCount = 0
    @State private var showDeveloperDebug = false

    init(selectedTab: Binding<Int>, api: PengPengAPI) {
        _selectedTab = selectedTab
        _viewModel = State(initialValue: ProfileViewModel(api: api))
    }

    var body: some View {
        @Bindable var session = session
        @Bindable var viewModel = viewModel
        let workoutStore = session.workoutStore

        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    ProfileHeaderCard(
                        userName: viewModel.userName,
                        weeklyWorkouts: workoutStore.hasTodayPresence ? 1 : 0,
                        todayBumps: store.pendingBumpCount + store.activeConversations.count,
                        activityRingPercent: min(100, workoutStore.displayWorkout.energyKcal / 6)
                    )
                    .onTapGesture {
                        developerTapCount += 1
                        if developerTapCount >= 5 {
                            showDeveloperDebug = true
                            developerTapCount = 0
                        }
                    }
                    TodayWorkoutSection(
                        workout: workoutStore.displayWorkout,
                        isAuthenticated: session.isAuthenticated,
                        needsHealthAuthorization: workoutStore.needsHealthAuthorization,
                        healthKitUnavailable: workoutStore.healthKitUnavailable,
                        hasNoCandidates: workoutStore.hasNoCandidates,
                        candidates: workoutStore.candidates,
                        selectedCandidateID: workoutStore.selectedCandidateID,
                        hasPublishedPresence: workoutStore.hasTodayPresence,
                        isSyncing: workoutStore.isSyncing,
                        canSync: workoutStore.canSync,
                        onRequestHealthAccess: {
                            Task { await workoutStore.requestHealthAccess() }
                        },
                        onSelectCandidate: { id in
                            workoutStore.selectCandidate(id)
                        },
                        onSync: session.isAuthenticated ? {
                            Task { await workoutStore.syncTodayPresence() }
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

                    if let error = viewModel.lastError ?? workoutStore.lastError {
                        Text(error)
                            .font(.system(size: 13))
                            .foregroundStyle(.red)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }

                    #if DEBUG
                    NavigationLink {
                        DeveloperDebugView(session: session, conversationStore: store)
                    } label: {
                        Text("开发者")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(AppTheme.secondaryText)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                    }
                    #endif
                }
                .padding(16)
            }
            .background(AppTheme.background)
            .navigationTitle("我")
            .navigationBarTitleDisplayMode(.large)
            .refreshable {
                await viewModel.load()
                await workoutStore.refresh()
                await store.refresh()
            }
            .task {
                await viewModel.load()
                await workoutStore.refresh()
            }
            .navigationDestination(isPresented: $showDeveloperDebug) {
                DeveloperDebugView(session: session, conversationStore: store)
            }
        }
    }
}

#Preview {
    ProfileView(selectedTab: .constant(2), api: PengPengAPI())
        .environment(AppSession())
        .environment(ConversationStore())
}
