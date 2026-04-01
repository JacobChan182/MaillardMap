import SwiftUI
import MapKit

struct BigBackMapView: View {
    @EnvironmentObject var vm: MapViewModel
    var onSelectRestaurant: (String, String) -> Void

    private var regionBinding: Binding<MKCoordinateRegion> {
        Binding(
            get: { vm.region },
            set: { newRegion in vm.onRegionChange(newRegion) }
        )
    }

    var body: some View {
        Map(
            coordinateRegion: regionBinding,
            interactionModes: .all,
            showsUserLocation: true,
            annotationItems: vm.pins,
            annotationContent: { pin in
                MapAnnotation(coordinate: pin.coordinate) {
                    Button {
                        onSelectRestaurant(pin.restaurantId, pin.restaurantName)
                    } label: {
                        if pin.isHeat {
                            Circle()
                                .fill(Color.orange.opacity(0.8))
                                .frame(width: 14, height: 14)
                                .shadow(radius: 1)
                        } else {
                            Image(systemName: "mappin.circle.fill")
                                .font(.title)
                                .foregroundStyle(.orange)
                                .shadow(radius: 1)
                        }
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Posts at \(pin.restaurantName)")
                }
            }
        )
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
    BigBackMapView { _, _ in }
        .environmentObject(MapViewModel(api: .live()))
}
