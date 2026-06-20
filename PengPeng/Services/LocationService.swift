import CoreLocation
import Foundation

enum LocationServiceError: LocalizedError {
    case denied
    case unavailable
    case timedOut

    var errorDescription: String? {
        switch self {
        case .denied:
            "未获得位置权限，将使用上次或默认模糊区域"
        case .unavailable:
            "暂时无法获取位置"
        case .timedOut:
            "定位超时，将使用上次或默认模糊区域"
        }
    }
}

@MainActor
final class LocationService: NSObject, CLLocationManagerDelegate {
    private let manager = CLLocationManager()
    private var continuation: CheckedContinuation<CLLocation, Error>?

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyHundredMeters
    }

    var authorizationStatus: CLAuthorizationStatus {
        manager.authorizationStatus
    }

    func requestWhenInUseAuthorization() {
        manager.requestWhenInUseAuthorization()
    }

    func requestLocation() async throws -> CLLocation {
        let status = manager.authorizationStatus
        switch status {
        case .notDetermined:
            manager.requestWhenInUseAuthorization()
            try await waitForAuthorization()
        case .denied, .restricted:
            throw LocationServiceError.denied
        case .authorizedAlways, .authorizedWhenInUse:
            break
        @unknown default:
            throw LocationServiceError.unavailable
        }

        return try await withCheckedThrowingContinuation { continuation in
            self.continuation = continuation
            manager.requestLocation()
        }
    }

    private func waitForAuthorization() async throws {
        for _ in 0..<20 {
            try await Task.sleep(nanoseconds: 200_000_000)
            switch manager.authorizationStatus {
            case .authorizedAlways, .authorizedWhenInUse:
                return
            case .denied, .restricted:
                throw LocationServiceError.denied
            default:
                continue
            }
        }
        throw LocationServiceError.timedOut
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        Task { @MainActor in
            guard let location = locations.last else { return }
            continuation?.resume(returning: location)
            continuation = nil
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        Task { @MainActor in
            if let continuation {
                if (error as? CLError)?.code == .denied {
                    continuation.resume(throwing: LocationServiceError.denied)
                } else {
                    continuation.resume(throwing: error)
                }
                self.continuation = nil
            }
        }
    }

    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {}
}
