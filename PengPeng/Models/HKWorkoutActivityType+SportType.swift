import HealthKit

extension HKWorkoutActivityType {
    var pengPengSport: SportType? {
        switch self {
        case .traditionalStrengthTraining,
             .functionalStrengthTraining,
             .coreTraining,
             .highIntensityIntervalTraining:
            return .traditionalStrength
        case .running:
            return .running
        case .walking, .hiking:
            return .walking
        case .downhillSkiing, .crossCountrySkiing, .snowboarding:
            return .skiing
        default:
            return nil
        }
    }
}

enum HealthKitAccessState: Equatable {
    case unavailable
    case notDetermined
    case ready

    var displayName: String {
        switch self {
        case .unavailable: "不可用（模拟器或未支持设备）"
        case .notDetermined: "未请求"
        case .ready: "已请求（读权限无法精确判断是否拒绝）"
        }
    }
}

extension SportType {
    static var supportedTitlesText: String {
        allCases.map(\.title).joined(separator: "、")
    }
}
