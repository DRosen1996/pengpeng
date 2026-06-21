import SwiftUI

struct NearbyView: View {
    @Environment(ConversationStore.self) private var store
    @Binding var selectedTab: Int
    @Bindable var viewModel: NearbyViewModel

    init(selectedTab: Binding<Int>, viewModel: NearbyViewModel) {
        _selectedTab = selectedTab
        self.viewModel = viewModel
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            NearbyMapView(
                zones: viewModel.zones,
                userCoordinate: viewModel.userCoordinate,
                cameraPosition: $viewModel.mapCameraPosition,
                highlightedZoneID: viewModel.highlightedZoneID,
                edgeToEdge: true,
                onZoneTap: { viewModel.openZone($0) }
            )
            .ignoresSafeArea()

            VStack(spacing: 0) {
                topOverlay
                Spacer()
            }

            bottomWorkoutPanel
        }
        .sheet(item: $viewModel.activeSheet) { route in
            sheetContent(for: route)
        }
        .onChange(of: viewModel.activeSheet) { _, newValue in
            if newValue == nil {
                viewModel.clearZoneHighlight()
            }
        }
        .task {
            await viewModel.load()
        }
        .refreshable {
            await viewModel.load()
            await store.refresh()
        }
    }

    private var bottomWorkoutPanel: some View {
        Group {
            switch viewModel.nearbyBottomWorkoutState {
            case .workout:
                BottomActionCard(
                    workout: viewModel.todayWorkout,
                    openCardCount: viewModel.defaultBumpZone.openCardCount,
                    hasPublishedPresence: viewModel.hasTodayPresence,
                    onBump: { viewModel.openDefaultBumpFlow() }
                )
            case .loading:
                BottomWorkoutPlaceholderCard(
                    title: "加载今日训练",
                    message: "正在读取 Apple 健康数据…",
                    showsProgress: true
                )
            case .needsHealthAuthorization:
                BottomWorkoutPlaceholderCard(
                    title: "连接 Apple 健康",
                    message: "读取今日 Watch 训练，看看附近谁也没白练",
                    buttonTitle: "连接 Apple 健康",
                    action: {
                        Task { await viewModel.requestHealthAccess() }
                    }
                )
            case .healthUnavailable:
                BottomWorkoutPlaceholderCard(
                    title: "无法读取健康数据",
                    message: "Apple 健康需要在 iPhone 真机上使用"
                )
            case .noCandidates:
                BottomWorkoutPlaceholderCard(
                    title: "今日暂无训练",
                    message: "还没有可展示的 \(SportType.supportedTitlesText) 训练（≥15 分钟）"
                )
            }
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 88)
    }

    private var topOverlay: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("附近")
                        .font(.system(size: 34, weight: .bold))
                        .foregroundStyle(AppTheme.primaryText)
                    Text("看看附近今天谁也没白练")
                        .font(.system(size: 14))
                        .foregroundStyle(AppTheme.secondaryText)
                }
                Spacer()
                Button("重置视野") {
                    viewModel.resetMapFocus()
                }
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(AppTheme.primaryText)
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(.ultraThinMaterial)
                .clipShape(Capsule())
            }

            HStack {
                mapBadge("附近 · 模糊范围")
                Spacer()
                mapBadge("3km 内")
            }

            if viewModel.isAuthenticated && !viewModel.hasTodayPresence {
                Text("请先在「我」页同步今日运动，才能被附近的人看到")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(AppTheme.primaryText)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(AppTheme.chipBackground)
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
        .padding(.bottom, 20)
        .background {
            LinearGradient(
                colors: [
                    Color.white.opacity(0.88),
                    Color.white.opacity(0.45),
                    Color.white.opacity(0)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea(edges: .top)
        }
    }

    private func mapBadge(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 11, weight: .medium))
            .foregroundStyle(AppTheme.secondaryText)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(.ultraThinMaterial)
            .clipShape(Capsule())
    }

    @ViewBuilder
    private func sheetContent(for route: NearbySheetRoute) -> some View {
        switch route {
        case .zoneDetail(let zone):
            SportZoneSheet(zone: zone) {
                viewModel.openUserList(for: zone)
            }
        case .userList:
            SameSportUsersSheet(users: viewModel.sameSportUsers) { user in
                viewModel.bump(user: user)
            }
        case .sportTopic(let user):
            SportTopicView(
                partner: user,
                topics: viewModel.sportTopics,
                selectedTopic: Binding(
                    get: { viewModel.selectedTopic },
                    set: { viewModel.selectTopic($0) }
                ),
                bumpSent: viewModel.bumpSent,
                conversation: { viewModel.conversation(for: $0) },
                onTopicSelect: { topic in
                    guard !viewModel.bumpSent else { return }
                    Task {
                        let sent = await store.sendBumpFromNearby(partner: user, topic: topic)
                        if sent {
                            viewModel.markBumpSent()
                        }
                    }
                }
            )
        }
    }
}

#Preview {
    let api = PengPengAPI()
    NearbyView(
        selectedTab: .constant(0),
        viewModel: NearbyViewModel(
            api: api,
            workoutStore: TodayWorkoutStore(
                api: api,
                healthKit: HealthKitService(),
                location: LocationService()
            )
        )
    )
    .environment(ConversationStore(api: api))
}
