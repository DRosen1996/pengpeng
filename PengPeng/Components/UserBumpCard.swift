import SwiftUI

struct UserBumpCard: View {
    let user: NearbyUser
    let onBump: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 6) {
                Text(user.name)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(AppTheme.primaryText)
                Text("\(user.sportLabel) · \(user.durationMinutes) 分钟")
                    .font(.system(size: 14))
                    .foregroundStyle(AppTheme.secondaryText)
                Text(user.streakLabel)
                    .font(.system(size: 13))
                    .foregroundStyle(AppTheme.tertiaryText)
                Text(user.focusLabel)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(AppTheme.primaryText)
                    .padding(.top, 2)
            }
            Spacer(minLength: 8)
            Button("碰碰", action: onBump)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.white)
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(AppTheme.accent)
                .clipShape(Capsule())
                .buttonStyle(.plain)
        }
        .padding(16)
        .background(AppTheme.surface)
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadius, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: AppTheme.cornerRadius, style: .continuous)
                .stroke(AppTheme.divider, lineWidth: 1)
        )
    }
}
