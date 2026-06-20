import CoreLocation
import Foundation
import MapKit
import SwiftUI

struct SportZone: Identifiable, Hashable {
    let id: String
    let sport: SportType
    let nearbyCount: Int
    let openCardCount: Int
    let latitude: Double
    let longitude: Double

    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }

    var displayTitle: String { sport.fullTitle }

    /// 点击热区后用于 MapKit 聚焦的相机
    var focusCamera: MapCamera {
        MapCamera(
            centerCoordinate: coordinate,
            distance: 3_800,
            heading: 0,
            pitch: 0
        )
    }
}
