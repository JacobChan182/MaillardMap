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
                            vm.showCalloutForMapPin(
                                restaurantId: pin.restaurantId,
                                name: pin.restaurantName,
                                coordinate: pin.coordinate
                            )
                        } label: {
                            if pin.isHeat {
                                Circle()
                                    .fill(Color.orange.opacity(0.8))
                                    .frame(width: 14, height: 14)
                                    .shadow(radius: 1)
                            } else {
                                MapMappinPinStyle(color: .orange)
                            }
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Show place card for \(pin.restaurantName)")
                    }
                case .temporaryGrayPin(_, let coordinate):
                    Annotation("", coordinate: coordinate) {
                        Circle()
                            .fill(Color.gray.opacity(0.8))
                            .frame(width: 14, height: 14)
                            .shadow(radius: 1)
                            .accessibilityHidden(true)
                    }
                case .callout(let c):
                    // Card only: the feed pin at this coordinate stays the marker; anchor the card’s bottom to the venue with a small gap so it sits just above the existing pin.
                    Annotation("", coordinate: item.coordinate, anchor: .bottom) {
                        Button {
                            onSelectRestaurant(c.restaurantId, c.name)
                        } label: {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(c.name)
                                    .font(.headline)
                                    .foregroundStyle(.black)
                                    .fixedSize(horizontal: false, vertical: true)
                                if let addr = c.address, !addr.isEmpty {
                                    Text(addr)
                                        .font(.caption)
                                        .foregroundStyle(Color(white: 0.38))
                                        .fixedSize(horizontal: false, vertical: true)
                                }
                            }
                            .padding(10)
                            .frame(maxWidth: 240, alignment: .leading)
                            .background(Color.white)
                            .cornerRadius(10)
                            .shadow(color: .black.opacity(0.25), radius: 4, y: 2)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Posts at \(c.name)")
                        // Keep the pin (centered on this coordinate) clear: space below the card ≈ half a title mappin + shadow.
                        .padding(.bottom, 38)
                    }
                }
            }
        }
        .onMapCameraChange(frequency: .onEnd) { context in
            vm.onMapCameraChangeEnded(region: context.region)
        }
    }
}

/// Same layout as feed zoomed-in pins (`mappin.circle.fill`), parameterized color (orange vs gray discovery pin).
private struct MapMappinPinStyle: View {
    let color: Color

    var body: some View {
        Image(systemName: "mappin.circle.fill")
            .font(.title)
            .foregroundStyle(color)
            .shadow(radius: 1)
    }
}

#Preview {
    BigBackMapView { _, _ in }
        .environmentObject(MapViewModel(api: .live()))
}
