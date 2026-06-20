import Foundation

struct NearbyUser: Identifiable, Hashable {
    let id: String
    let name: String
    let sportLabel: String
    let durationMinutes: Int
    let streakLabel: String
    let focusLabel: String
    let sport: SportType
}
