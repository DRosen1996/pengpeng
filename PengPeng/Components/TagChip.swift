import SwiftUI

struct TagChip: View {
    let title: String

    var body: some View {
        Text(title)
            .font(.system(size: 13, weight: .medium))
            .foregroundStyle(AppTheme.primaryText)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(AppTheme.chipBackground)
            .clipShape(Capsule())
    }
}
