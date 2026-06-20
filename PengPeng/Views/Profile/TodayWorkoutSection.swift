import SwiftUI

struct TodayWorkoutSection: View {
    let workout: WorkoutSummary
    var isAuthenticated: Bool = true
    var needsHealthAuthorization: Bool = false
    var healthKitUnavailable: Bool = false
    var hasNoCandidates: Bool = false
    var candidates: [TodayWorkoutCandidate] = []
    var selectedCandidateID: String?
    var hasPublishedPresence: Bool = false
    var isSyncing: Bool = false
    var canSync: Bool = false
    var onRequestHealthAccess: (() -> Void)?
    var onSelectCandidate: ((String) -> Void)?
    var onSync: (() -> Void)?

    private var showWorkoutSummary: Bool {
        !needsHealthAuthorization && !hasNoCandidates && (hasPublishedPresence || selectedCandidateID != nil)
    }

    var body: some View {
        SectionCard(title: "今日没白戴") {
            VStack(alignment: .leading, spacing: 12) {
                if !isAuthenticated {
                    mockContent
                } else if needsHealthAuthorization {
                    healthAuthContent
                } else if healthKitUnavailable {
                    unavailableContent
                } else if hasNoCandidates {
                    emptyContent
                } else {
                    if candidates.count > 1, !hasPublishedPresence {
                        WorkoutPicker(
                            candidates: candidates,
                            selectedCandidateID: Binding(
                                get: { selectedCandidateID },
                                set: { newValue in
                                    if let newValue {
                                        onSelectCandidate?(newValue)
                                    }
                                }
                            ),
                            onSelect: { candidate in
                                onSelectCandidate?(candidate.id)
                            }
                        )
                    }

                    if showWorkoutSummary {
                        workoutSummaryContent
                    } else if candidates.count > 1 {
                        Text("请选择一条训练后再同步到附近")
                            .font(.system(size: 14))
                            .foregroundStyle(AppTheme.secondaryText)
                    }

                    syncControls
                }
            }
        }
    }

    private var mockContent: some View {
        VStack(alignment: .leading, spacing: 8) {
            workoutSummaryContent
            Text("登录后可同步 Apple 健康中的真实训练")
                .font(.system(size: 13))
                .foregroundStyle(AppTheme.secondaryText)
        }
    }

    private var healthAuthContent: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("连接 Apple 健康，读取今日 Watch 训练记录")
                .font(.system(size: 14))
                .foregroundStyle(AppTheme.secondaryText)
            if let onRequestHealthAccess {
                PrimaryButton(title: "连接 Apple 健康", action: onRequestHealthAccess)
            }
        }
    }

    private var unavailableContent: some View {
        Text("Apple 健康数据需要在真机上读取，请使用 iPhone 真机运行")
            .font(.system(size: 14))
            .foregroundStyle(AppTheme.secondaryText)
            .fixedSize(horizontal: false, vertical: true)
    }

    private var emptyContent: some View {
        Text("今日还没有可同步的 \(SportType.supportedTitlesText) 训练（≥15 分钟）")
            .font(.system(size: 14))
            .foregroundStyle(AppTheme.secondaryText)
            .fixedSize(horizontal: false, vertical: true)
    }

    private var workoutSummaryContent: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("\(workout.sport.title)训练 \(workout.durationMinutes) 分钟")
                .font(.system(size: 16, weight: .semibold))
            Text("活动能量 \(workout.energyKcal) kcal · 附近同项目 \(workout.nearbySameSportCount) 人 · 可碰碰")
                .font(.system(size: 14))
                .foregroundStyle(AppTheme.secondaryText)
        }
    }

    @ViewBuilder
    private var syncControls: some View {
        if isAuthenticated, let onSync {
            if hasPublishedPresence {
                Label("已同步到附近", systemImage: "checkmark.circle.fill")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(AppTheme.accent)
            } else if canSync {
                PrimaryButton(title: isSyncing ? "同步中…" : "同步今日运动") {
                    onSync()
                }
                .disabled(isSyncing)
            }
        }
    }
}

#Preview {
    TodayWorkoutSection(
        workout: MockData.todayWorkout,
        isAuthenticated: true,
        candidates: [],
        selectedCandidateID: nil,
        canSync: true,
        onSync: {}
    )
    .padding()
}
