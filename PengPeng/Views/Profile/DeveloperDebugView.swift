import SwiftUI

struct DeveloperDebugView: View {
    @State private var viewModel: DeveloperDebugViewModel

    init(session: AppSession, conversationStore: ConversationStore) {
        _viewModel = State(initialValue: DeveloperDebugViewModel(session: session, conversationStore: conversationStore))
    }

    var body: some View {
        @Bindable var viewModel = viewModel

        ScrollView {
            VStack(spacing: 16) {
                if let snapshot = viewModel.snapshot {
                    debugSection(title: "权限", rows: snapshot.permissionRows)
                    debugSection(title: "运动 / Presence", rows: snapshot.workoutRows)
                    debugSection(title: "位置 / Geohash", rows: snapshot.locationRows)
                    debugSection(title: "账户", rows: snapshot.accountRows)
                    debugSection(title: "Realtime / 消息", rows: snapshot.realtimeRows)
                } else if viewModel.isLoading {
                    ProgressView("加载中…")
                        .frame(maxWidth: .infinity, minHeight: 120)
                }

                actionSection(viewModel: viewModel)

                if let message = viewModel.actionMessage {
                    Text(message)
                        .font(.system(size: 13))
                        .foregroundStyle(AppTheme.accent)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }

                Text("说明：HealthKit 读权限在 iOS 上无法精确区分「未请求」与「用户拒绝」，以系统设置为准。")
                    .font(.system(size: 12))
                    .foregroundStyle(AppTheme.secondaryText)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(16)
        }
        .background(AppTheme.background)
        .navigationTitle("开发者")
        .navigationBarTitleDisplayMode(.inline)
        .refreshable {
            await viewModel.refresh()
        }
        .task {
            await viewModel.refresh()
        }
        .navigationDestination(isPresented: $viewModel.showLocationPicker) {
            DeveloperLocationPickerView(
                initialCoordinate: viewModel.locationPickerInitialCoordinate,
                isSaving: viewModel.isUpdatingLocation,
                onSave: { coordinate in
                    Task { await viewModel.updateUserLocation(at: coordinate) }
                },
                onCancel: {
                    viewModel.showLocationPicker = false
                }
            )
            .id(viewModel.locationPickerSessionID)
        }
    }

    @ViewBuilder
    private func debugSection(title: String, rows: [DeveloperDebugSnapshot.Row]) -> some View {
        SectionCard(title: title) {
            VStack(spacing: 0) {
                ForEach(Array(rows.enumerated()), id: \.element.id) { index, row in
                    debugRow(label: row.label, value: row.value)
                    if index < rows.count - 1 {
                        Divider()
                    }
                }
            }
        }
    }

    private func debugRow(label: String, value: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Text(label)
                .font(.system(size: 14))
                .foregroundStyle(AppTheme.secondaryText)
                .frame(width: 120, alignment: .leading)
            Text(value)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(AppTheme.primaryText)
                .frame(maxWidth: .infinity, alignment: .leading)
                .textSelection(.enabled)
        }
        .padding(.vertical, 10)
    }

    @ViewBuilder
    private func actionSection(viewModel: DeveloperDebugViewModel) -> some View {
        SectionCard(title: "操作") {
            VStack(spacing: 10) {
                PrimaryButton(title: "刷新状态") {
                    Task { await viewModel.refresh() }
                }

                PrimaryButton(title: "请求 HealthKit 授权") {
                    Task { await viewModel.requestHealthAccess() }
                }

                PrimaryButton(title: "请求位置授权") {
                    viewModel.requestLocationAccess()
                }

                PrimaryButton(title: viewModel.isProbingLocation ? "定位探测中…" : "探测当前位置 → geohash") {
                    Task { await viewModel.probeLocation() }
                }
                .disabled(viewModel.isProbingLocation)

                PrimaryButton(title: "地图选点改定位") {
                    viewModel.openLocationPicker()
                }
                .disabled(!viewModel.isAuthenticated || viewModel.isUpdatingLocation)

                if let settingsURL = URL(string: UIApplication.openSettingsURLString) {
                    Link(destination: settingsURL) {
                        Text("打开系统设置")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(AppTheme.accent)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(AppTheme.chipBackground)
                            .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadius, style: .continuous))
                    }
                }
            }
        }
    }
}

#Preview {
    NavigationStack {
        DeveloperDebugView(session: AppSession(), conversationStore: ConversationStore())
    }
}
