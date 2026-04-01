import Foundation
import MapKit
import CoreLocation

@MainActor
final class MapViewModel: NSObject, ObservableObject, CLLocationManagerDelegate {
    @Published var region = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194),
        span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
    )
    @Published var pins: [MapPin] = []
    @Published var showHeatmap = true
    @Published var isLoading = false
    @Published var errorMessage: String?

    private let api: APIClient

    private var posts: [Post] = []
    private let manager = CLLocationManager()

    // Threshold for zoom level: span < 0.01 = zoomed in = show pins
    let zoomThreshold: Double = 0.01

    init(api: APIClient = .live()) {
        self.api = api
        super.init()
        manager.delegate = self
        manager.requestWhenInUseAuthorization()
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.first else { return }
        Task { @MainActor in
            region.center = location.coordinate
            updateAnnotations()
        }
    }

    func onRegionChange(_ newRegion: MKCoordinateRegion) {
        region = newRegion
        let zoomLevel = min(newRegion.span.latitudeDelta, newRegion.span.longitudeDelta)
        showHeatmap = zoomLevel >= zoomThreshold
        updateAnnotations()
    }

    func loadPosts() async {
        isLoading = true
        defer { isLoading = false }
        do {
            posts = try await api.getFeed()
            updateAnnotations()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func updateAnnotations() {
        pins = posts.map { post in
            MapPin(
                coordinate: CLLocationCoordinate2D(latitude: post.lat, longitude: post.lng),
                title: post.restaurantName,
                subtitle: post.comment ?? "",
                isHeat: showHeatmap
            )
        }
    }
}

struct MapPin: Identifiable {
    let id = UUID()
    let coordinate: CLLocationCoordinate2D
    let title: String
    let subtitle: String
    let isHeat: Bool
}
