import Foundation

enum SportType: String, CaseIterable, Identifiable, Hashable {
    case traditionalStrength
    case running
    case walking
    case skiing

    var id: String { rawValue }

    var emoji: String {
        switch self {
        case .traditionalStrength: "🏋️"
        case .running: "🏃"
        case .walking: "🚶"
        case .skiing: "⛷️"
        }
    }

    var title: String {
        switch self {
        case .traditionalStrength: "传统力量"
        case .running: "跑步"
        case .walking: "步行"
        case .skiing: "滑雪"
        }
    }

    var fullTitle: String {
        "\(emoji) \(title)"
    }
}
