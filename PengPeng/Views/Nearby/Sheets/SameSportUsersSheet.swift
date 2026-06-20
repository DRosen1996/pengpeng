import SwiftUI

struct SameSportUsersSheet: View {
    let users: [NearbyUser]
    let onBumpUser: (NearbyUser) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            SheetHeader(title: "今天也练了的人")
            ScrollView {
                VStack(spacing: 12) {
                    ForEach(users) { user in
                        UserBumpCard(user: user) {
                            onBumpUser(user)
                        }
                    }
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 8)
        .padding(.bottom, 24)
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }
}
