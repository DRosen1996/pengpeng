import SwiftUI

struct SportZoneMapAnnotation: View {
    let zone: SportZone
    var isHighlighted = false
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 4) {
                ZStack {
                    Circle()
                        .fill(AppTheme.zonePulse)
                        .frame(width: pulseSize, height: pulseSize)
                    Circle()
                        .fill(Color.white)
                        .frame(width: 56, height: 56)
                        .shadow(color: .black.opacity(isHighlighted ? 0.16 : 0.08), radius: isHighlighted ? 10 : 8, y: 2)
                        .overlay(
                            Circle()
                                .stroke(isHighlighted ? AppTheme.accent : Color.clear, lineWidth: 2)
                        )
                    VStack(spacing: 2) {
                        Text(zone.sport.emoji)
                            .font(.system(size: 20))
                        Text("\(zone.nearbyCount)")
                            .font(.system(size: 13, weight: .bold, design: .rounded))
                            .foregroundStyle(AppTheme.primaryText)
                    }
                }
                Text(zone.sport.title)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(AppTheme.primaryText)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(.ultraThinMaterial)
                    .clipShape(Capsule())
            }
        }
        .buttonStyle(.plain)
    }

    private var pulseSize: CGFloat {
        let base: CGFloat = 72
        let scale = min(CGFloat(zone.nearbyCount) / 20, 1.4)
        return base + scale * 12
    }
}

struct UserLocationMarker: View {
    var body: some View {
        ZStack {
            Circle()
                .fill(Color.black.opacity(0.12))
                .frame(width: 28, height: 28)
            Circle()
                .fill(Color.white)
                .frame(width: 14, height: 14)
                .overlay(
                    Circle()
                        .stroke(AppTheme.accent, lineWidth: 3)
                )
        }
    }
}

#Preview {
    SportZoneMapAnnotation(zone: MockData.strengthZone, isHighlighted: true) {}
}
