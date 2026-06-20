import SwiftUI

struct SportZoneSheet: View {
    let zone: SportZone
    let onBump: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            SheetHeader(title: zone.displayTitle)
            VStack(alignment: .leading, spacing: 12) {
                infoLine("附近 \(zone.nearbyCount) 人今天也在练")
                infoLine("\(zone.openCardCount) 人开放运动名片")
                infoLine("附近 3km，模糊范围")
            }
            PrimaryButton(title: "碰碰", action: onBump)
        }
        .padding(.horizontal, 20)
        .padding(.top, 8)
        .padding(.bottom, 24)
        .presentationDetents([.medium])
        .presentationDragIndicator(.visible)
    }

    private func infoLine(_ text: String) -> some View {
        HStack(spacing: 8) {
            Circle()
                .fill(AppTheme.primaryText)
                .frame(width: 5, height: 5)
            Text(text)
                .font(.system(size: 15))
                .foregroundStyle(AppTheme.secondaryText)
        }
    }
}
