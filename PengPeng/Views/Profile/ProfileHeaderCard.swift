import SwiftUI

struct ProfileHeaderCard: View {
    let userName: String
    let weeklyWorkouts: Int
    let todayBumps: Int
    let activityRingPercent: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 6) {
                Text(userName)
                    .font(.system(size: 26, weight: .bold))
                    .foregroundStyle(.white)
                Text("开放同项目运动碰碰")
                    .font(.system(size: 14))
                    .foregroundStyle(AppTheme.cardDarkSecondary)
            }
            StatRow(
                items: [
                    ("\(weeklyWorkouts)", "本周运动"),
                    ("\(todayBumps)", "今日碰碰"),
                    ("\(activityRingPercent)%", "活动环")
                ],
                onDarkBackground: true
            )
        }
        .padding(20)
        .background(AppTheme.cardDark)
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.cardRadius, style: .continuous))
    }
}
