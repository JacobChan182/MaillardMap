import Foundation
import MapKit
import CoreLocation

@MainActor
final class MapViewModel: NSObject, ObservableObject, CLLocationManagerDelegate {
    @Published var region = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194),
        span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
    )
    /// The actual user location, separate from the displayed region
    @Published var userLocation: CLLocationCoordinate2D?
    @Published var pins: [MapPin] = []
    @Published var showHeatmap = true
    @Published var isLoading = false
    @Published var errorMessage: String?

    private let api: APIClient

    private var posts: [Post] = []
    private let manager = CLLocationManager()
    private var hasCenteredOnUserLocation = false

    // Threshold for zoom level: span < 0.01 = zoomed in = show pins
    let zoomThreshold: Double = 0.01

    /// For restaurant search: GPS when available, otherwise the map’s visible center (initial default is SF, not NYC).
    var searchAnchor: CLLocationCoordinate2D {
        userLocation ?? region.center
    }

    init(api: APIClient = .live()) {
        self.api = api
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyHundredMeters
        manager.requestWhenInUseAuthorization()
        startLocationUpdatesIfAllowed()
    }

    private func startLocationUpdatesIfAllowed() {
        switch manager.authorizationStatus {
        case .authorizedAlways, .authorizedWhenInUse:
            manager.startUpdatingLocation()
        default:
            break
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.first else { return }
        Task { @MainActor in
            let coordinate = location.coordinate
            // Center on first known user location
            if !hasCenteredOnUserLocation {
                region = MKCoordinateRegion(
                    center: coordinate,
                    span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
                )
            }
            userLocation = coordinate
            updateAnnotations()
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
        Task { @MainActor in
            switch status {
            case .authorizedAlways, .authorizedWhenInUse:
                self.startLocationUpdatesIfAllowed()
            case .denied, .restricted:
                errorMessage = "Location access denied. Enable it in Settings to see your location on the map."
            case .notDetermined:
                manager.requestWhenInUseAuthorization()
            @unknown default:
                break
            }
        }
    }

    func onRegionChange(_ newRegion: MKCoordinateRegion) {
        region = newRegion
        let zoomLevel = min(newRegion.span.latitudeDelta, newRegion.span.longitudeDelta)
        showHeatmap = zoomLevel > zoomThreshold
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
