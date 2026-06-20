import SwiftUI

struct StatRow: View {
    let items: [(String, String)]
    var onDarkBackground = false

    var body: some View {
        HStack(spacing: 0) {
            ForEach(Array(items.enumerated()), id: \.offset) { index, item in
                VStack(spacing: 4) {
                    Text(item.0)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(valueColor)
                    Text(item.1)
                        .font(.system(size: 12))
                        .foregroundStyle(labelColor)
                }
                .frame(maxWidth: .infinity)
                if index < items.count - 1 {
                    Rectangle()
                        .fill(onDarkBackground ? Color.white.opacity(0.2) : AppTheme.divider)
                        .frame(width: 1, height: 32)
                }
            }
        }
    }

    private var valueColor: Color {
        onDarkBackground ? .white : AppTheme.primaryText
    }

    private var labelColor: Color {
        onDarkBackground ? AppTheme.cardDarkSecondary : AppTheme.secondaryText
    }
}
