import MapKit
import SwiftUI

struct NearbyMapView: View {
    let zones: [SportZone]
    @Binding var cameraPosition: MapCameraPosition
    var highlightedZoneID: String?
    var edgeToEdge: Bool = false
    let onZoneTap: (SportZone) -> Void

    var body: some View {
        Map(position: $cameraPosition, interactionModes: [.pan, .zoom, .rotate, .pitch]) {
            fuzzyRangeCircle
            userAnnotation
            zoneAnnotations
        }
        .mapStyle(.standard(elevation: .realistic, pointsOfInterest: .excludingAll, showsTraffic: false))
        .mapControlVisibility(.hidden)
        .modifier(MapFrameModifier(edgeToEdge: edgeToEdge))
        .onMapCameraChange(frequency: .onEnd) { context in
            cameraPosition = .camera(context.camera)
        }
    }

    @MapContentBuilder
    private var fuzzyRangeCircle: some MapContent {
        MapCircle(center: MockData.mapCenter, radius: MockData.fuzzyRadiusMeters)
            .foregroundStyle(Color.black.opacity(0.05))
            .stroke(Color.black.opacity(0.14), lineWidth: 1.5)
    }

    @MapContentBuilder
    private var userAnnotation: some MapContent {
        Annotation("我", coordinate: MockData.userCoordinate, anchor: .center) {
            UserLocationMarker()
        }
    }

    @MapContentBuilder
    private var zoneAnnotations: some MapContent {
        ForEach(zones) { zone in
            Annotation(zone.sport.title, coordinate: zone.coordinate, anchor: .bottom) {
                SportZoneMapAnnotation(
                    zone: zone,
                    isHighlighted: highlightedZoneID == zone.id,
                    onTap: { onZoneTap(zone) }
                )
            }
        }
    }
}

private struct MapFrameModifier: ViewModifier {
    let edgeToEdge: Bool

    func body(content: Content) -> some View {
        if edgeToEdge {
            content
        } else {
            content
                .clipShape(RoundedRectangle(cornerRadius: AppTheme.cardRadius, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: AppTheme.cardRadius, style: .continuous)
                        .stroke(AppTheme.divider, lineWidth: 1)
                )
        }
    }
}

#Preview {
    NearbyMapView(
        zones: MockData.sportZones,
        cameraPosition: .constant(MockData.nearbyCameraPosition),
        edgeToEdge: true,
        onZoneTap: { _ in }
    )
}
