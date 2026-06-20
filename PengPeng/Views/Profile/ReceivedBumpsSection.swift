import SwiftUI

struct ReceivedBumpsSection: View {
    let bumps: [PendingBump]
    let onTap: () -> Void

    var body: some View {
        SectionCard(title: "收到的碰碰") {
            if bumps.isEmpty {
                Text("暂无待处理碰碰")
                    .font(.system(size: 14))
                    .foregroundStyle(AppTheme.secondaryText)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 8)
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(bumps.enumerated()), id: \.element.id) { index, bump in
                        HStack(alignment: .top, spacing: 10) {
                            Circle()
                                .fill(AppTheme.primaryText)
                                .frame(width: 6, height: 6)
                                .padding(.top, 6)
                            Text(bump.message)
                                .font(.system(size: 14))
                                .foregroundStyle(AppTheme.primaryText)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .padding(.vertical, 12)
                        if index < bumps.count - 1 {
                            Divider()
                        }
                    }
                }
            }
        }
        .contentShape(Rectangle())
        .onTapGesture(perform: onTap)
    }
}
