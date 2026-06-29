import CoreLocation
import MapKit
import SwiftUI

struct DeveloperLocationPickerView: View {
    let initialCoordinate: CLLocationCoordinate2D
    let isSaving: Bool
    let onSave: (CLLocationCoordinate2D) -> Void
    let onCancel: () -> Void

    @State private var selectedCoordinate: CLLocationCoordinate2D
    @State private var cameraPosition: MapCameraPosition

    init(
        initialCoordinate: CLLocationCoordinate2D,
        isSaving: Bool,
        onSave: @escaping (CLLocationCoordinate2D) -> Void,
        onCancel: @escaping () -> Void
    ) {
        self.initialCoordinate = initialCoordinate
        self.isSaving = isSaving
        self.onSave = onSave
        self.onCancel = onCancel
        _selectedCoordinate = State(initialValue: initialCoordinate)
        _cameraPosition = State(initialValue: Self.cameraPosition(for: initialCoordinate))
    }

    private var previewGeohash: String {
        Geohash.encode(
            latitude: selectedCoordinate.latitude,
            longitude: selectedCoordinate.longitude,
            precision: 5
        )
    }

    var body: some View {
        VStack(spacing: 0) {
            mapSection

            VStack(alignment: .leading, spacing: 12) {
                Text("拖动地图，使中心标记对准目标位置；保存后写入 Profile geohash，若已有今日 presence 会一并更新（精度 5）。")
                    .font(.system(size: 13))
                    .foregroundStyle(AppTheme.secondaryText)

                VStack(spacing: 6) {
                    infoRow(label: "坐标", value: coordinateText(selectedCoordinate))
                    infoRow(label: "Geohash", value: previewGeohash)
                }

                HStack(spacing: 10) {
                    Button("取消") {
                        onCancel()
                    }
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(AppTheme.primaryText)
                    .frame(maxWidth: .infinity)
                    .frame(height: AppTheme.buttonHeight)
                    .background(AppTheme.chipBackground)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

                    PrimaryButton(title: isSaving ? "保存中…" : "保存定位") {
                        onSave(selectedCoordinate)
                    }
                    .disabled(isSaving)
                }
            }
            .padding(16)
            .background(AppTheme.background)
        }
        .background(AppTheme.background)
        .navigationTitle("选择定位")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var mapSection: some View {
        Map(position: $cameraPosition, interactionModes: [.pan, .zoom]) {
            MapCircle(center: selectedCoordinate, radius: MockData.fuzzyRadiusMeters)
                .foregroundStyle(Color.black.opacity(0.05))
                .stroke(Color.black.opacity(0.14), lineWidth: 1.5)
        }
        .mapStyle(.standard(elevation: .realistic, pointsOfInterest: .excludingAll, showsTraffic: false))
        .onMapCameraChange(frequency: .continuous) { context in
            selectedCoordinate = context.camera.centerCoordinate
        }
        .overlay {
            UserLocationMarker()
                .allowsHitTesting(false)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 360)
    }

    private func infoRow(label: String, value: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Text(label)
                .font(.system(size: 14))
                .foregroundStyle(AppTheme.secondaryText)
                .frame(width: 72, alignment: .leading)
            Text(value)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(AppTheme.primaryText)
                .frame(maxWidth: .infinity, alignment: .leading)
                .textSelection(.enabled)
        }
    }

    private func coordinateText(_ coordinate: CLLocationCoordinate2D) -> String {
        String(format: "%.5f, %.5f", coordinate.latitude, coordinate.longitude)
    }

    private static func cameraPosition(for coordinate: CLLocationCoordinate2D) -> MapCameraPosition {
        .camera(
            MapCamera(
                centerCoordinate: coordinate,
                distance: 4_500,
                heading: 0,
                pitch: 0
            )
        )
    }
}

#Preview {
    NavigationStack {
        DeveloperLocationPickerView(
            initialCoordinate: MockData.userCoordinate,
            isSaving: false,
            onSave: { _ in },
            onCancel: {}
        )
    }
}
