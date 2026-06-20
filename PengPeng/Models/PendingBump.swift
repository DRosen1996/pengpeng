import Foundation

enum BumpStatus: String, Hashable {
    case pending
    case accepted
    case dismissed
}

struct PendingBump: Identifiable, Hashable {
    let id: String
    let fromUser: NearbyUser
    let message: String
    var status: BumpStatus
    let receivedAt: Date
}
