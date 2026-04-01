import SwiftUI
import MapKit

struct BigBackMapView: View {
    @EnvironmentObject var vm: MapViewModel
    var onSelectRestaurant: (String, String) -> Void

    private var mapPositionBinding: Binding<MapCameraPosition> {
        Binding(
            get: { MapCameraPosition.region(vm.region) },
            set: { newPos in
                // `MapCameraPosition` is not an enum: use `region` (nil only when not representable as a rectangle).
                if let r = newPos.region {
                    vm.onRegionChange(r)
                }
            }
        )
    }

    var body: some View {
        Map(position: mapPositionBinding, interactionModes: .all) {
            UserAnnotation()
            ForEach(vm.mapAnnotations) { item in
                switch item {
                case .feed(let pin):
                    Annotation("", coordinate: item.coordinate) {
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
                case .callout(let c):
                    Annotation("", coordinate: item.coordinate) {
                        VStack(spacing: 6) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(c.name)
                                    .font(.headline)
                                    .foregroundStyle(.primary)
                                    .fixedSize(horizontal: false, vertical: true)
                                if let addr = c.address, !addr.isEmpty {
                                    Text(addr)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                        .fixedSize(horizontal: false, vertical: true)
                                }
                            }
                            .padding(10)
                            .frame(maxWidth: 240, alignment: .leading)
                            .background(Color.white)
                            .cornerRadius(10)
                            .shadow(color: .black.opacity(0.25), radius: 4, y: 2)
                            Image(systemName: "mappin.circle.fill")
                                .font(.title)
                                .foregroundStyle(.blue)
                                .shadow(radius: 1)
                        }
                        .offset(y: -10)
                    }
                }
            }
        }
        .onMapCameraChange(frequency: .onEnd) { context in
            vm.onMapCameraChangeEnded(region: context.region)
        }
    }
}

#Preview {
    BigBackMapView { _, _ in }
        .environmentObject(MapViewModel(api: .live()))
}
