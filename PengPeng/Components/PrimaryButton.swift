import SwiftUI

struct PrimaryButton: View {
    let title: String
    var style: Style = .dark
    let action: () -> Void

    enum Style {
        case dark
        case light
    }

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 16, weight: .semibold))
                .frame(maxWidth: .infinity)
                .frame(height: AppTheme.buttonHeight)
                .foregroundStyle(foregroundColor)
                .background(backgroundColor)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    private var foregroundColor: Color {
        switch style {
        case .dark: .white
        case .light: AppTheme.primaryText
        }
    }

    private var backgroundColor: Color {
        switch style {
        case .dark: AppTheme.accent
        case .light: AppTheme.surface
        }
    }
}
