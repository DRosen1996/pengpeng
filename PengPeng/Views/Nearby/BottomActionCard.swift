import SwiftUI

struct BottomActionCard: View {
    let workout: WorkoutSummary
    let openCardCount: Int
    let hasPublishedPresence: Bool
    let onBump: () -> Void

    private var headline: String {
        let prefix = hasPublishedPresence ? "刚完成" : "今日"
        return "\(prefix) · \(workout.sport.title) \(workout.durationMinutes) 分钟"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 6) {
                Text(headline)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.white)
                Text("附近 \(workout.nearbySameSportCount) 人今天也练了")
                    .font(.system(size: 14))
                    .foregroundStyle(AppTheme.cardDarkSecondary)
                Text("\(openCardCount) 人开放运动名片，可以碰碰。只基于运动事实，不展示精确轨迹。")
                    .font(.system(size: 13))
                    .foregroundStyle(AppTheme.cardDarkSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            PrimaryButton(title: "碰碰", action: onBump)
        }
        .padding(20)
        .background(AppTheme.cardDark)
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.cardRadius, style: .continuous))
        .shadow(color: .black.opacity(0.15), radius: 16, y: 8)
    }
}

struct BottomWorkoutPlaceholderCard: View {
    let title: String
    let message: String
    var showsProgress = false
    var buttonTitle: String?
    var action: (() -> Void)?

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 6) {
                Text(title)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.white)
                Text(message)
                    .font(.system(size: 14))
                    .foregroundStyle(AppTheme.cardDarkSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if showsProgress {
                ProgressView()
                    .tint(.white)
                    .frame(maxWidth: .infinity, minHeight: AppTheme.buttonHeight)
            } else if let buttonTitle, let action {
                PrimaryButton(title: buttonTitle, action: action)
            }
        }
        .padding(20)
        .background(AppTheme.cardDark)
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.cardRadius, style: .continuous))
        .shadow(color: .black.opacity(0.15), radius: 16, y: 8)
    }
}

#Preview("Workout") {
    BottomActionCard(
        workout: MockData.todayWorkout,
        openCardCount: 5,
        hasPublishedPresence: true,
        onBump: {}
    )
    .padding()
}

#Preview("Placeholder") {
    BottomWorkoutPlaceholderCard(
        title: "连接 Apple 健康",
        message: "读取今日 Watch 训练，看看附近谁也没白练",
        buttonTitle: "连接 Apple 健康",
        action: {}
    )
    .padding()
}
