import CoreLocation
import Foundation
import HealthKit

struct HealthKitDebugInfo: Equatable {
    let isAvailable: Bool
    let accessState: HealthKitAccessState
    let authorizationRequested: Bool
    let workoutAuthorization: String
    let activeEnergyAuthorization: String
}

struct DeveloperDebugSnapshot: Equatable {
    struct Row: Equatable, Identifiable {
        let id: String
        let label: String
        let value: String
    }

    let permissionRows: [Row]
    let workoutRows: [Row]
    let locationRows: [Row]
    let accountRows: [Row]
}

extension HKAuthorizationStatus {
    var displayName: String {
        switch self {
        case .notDetermined:
            "未决定"
        case .sharingDenied:
            "已拒绝 / 未授权读取"
        case .sharingAuthorized:
            "已授权"
        @unknown default:
            "未知"
        }
    }
}

extension CLAuthorizationStatus {
    var displayName: String {
        switch self {
        case .notDetermined:
            "未决定"
        case .restricted:
            "受限制"
        case .denied:
            "已拒绝"
        case .authorizedAlways:
            "始终允许"
        case .authorizedWhenInUse:
            "使用 App 期间"
        @unknown default:
            "未知"
        }
    }
}
