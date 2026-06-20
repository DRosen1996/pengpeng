import SwiftUI

struct BottomActionCard: View {
    let workout: WorkoutSummary
    let openCardCount: Int
    let onBump: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 6) {
                Text("刚完成 · \(workout.sport.title) \(workout.durationMinutes) 分钟")
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

#Preview {
    BottomActionCard(
        workout: MockData.todayWorkout,
        openCardCount: 5,
        onBump: {}
    )
    .padding()
}
