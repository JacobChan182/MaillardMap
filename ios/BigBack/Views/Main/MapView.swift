import SwiftUI
import MapKit

struct BigBackMapView: View {
    @EnvironmentObject var vm: MapViewModel

    var body: some View {
        Map(coordinateRegion: Binding(
            get: { vm.region },
            set: { vm.onRegionChange($0) }
        ), annotationItems: vm.pins) { pin in
            if vm.showHeatmap {
                MapMarker(coordinate: pin.coordinate)
            } else {
                MapMarker(coordinate: pin.coordinate, tint: .orange)
            }
        }
        .overlay {
            ZStack(alignment: .bottomTrailing) {
                Text(vm.showHeatmap ? "Zoom in for pins" : "Zoom out for heatmap")
                    .font(.caption2)
                    .padding(8)
                    .background(Color(uiColor: .systemBackground).opacity(0.85))
                    .cornerRadius(8)
                    .padding()
            }
        }
    }
}

#Preview {
    BigBackMapView()
        .environmentObject(MapViewModel())
}
