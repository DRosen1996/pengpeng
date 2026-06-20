import SwiftUI

struct TodayWorkoutSection: View {
    let workout: WorkoutSummary
    var hasPublishedPresence: Bool = true
    var isSyncing: Bool = false
    var onSync: (() -> Void)?

    var body: some View {
        SectionCard(title: "今日没白戴") {
            VStack(alignment: .leading, spacing: 12) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("\(workout.sport.title)训练 \(workout.durationMinutes) 分钟")
                        .font(.system(size: 16, weight: .semibold))
                    Text("活动能量 \(workout.energyKcal) kcal · 附近同项目 \(workout.nearbySameSportCount) 人 · 可碰碰")
                        .font(.system(size: 14))
                        .foregroundStyle(AppTheme.secondaryText)
                }

                if let onSync {
                    if hasPublishedPresence {
                        Label("已同步到附近", systemImage: "checkmark.circle.fill")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(AppTheme.accent)
                    } else {
                        PrimaryButton(title: isSyncing ? "同步中…" : "同步今日运动") {
                            onSync()
                        }
                        .disabled(isSyncing)
                    }
                }
            }
        }
    }
}
