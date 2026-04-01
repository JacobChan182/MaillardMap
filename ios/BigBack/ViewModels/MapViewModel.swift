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
    /// Temporary blue callout from a post’s “restaurant” chip; cleared when the user pans/zooms the map.
    @Published var restaurantCallout: MapRestaurantCallout?
    /// Region snapshot when the callout was shown (iOS 17 has no `MapCameraUpdateContext.reason`; compare camera to this to detect user moves).
    private var calloutDismissRegionAnchor: MKCoordinateRegion?
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

    /// Feed / post list: jump map here with the white callout pin.
    func focusRestaurantFromPost(_ post: Post) {
        restaurantCallout = MapRestaurantCallout(
            name: post.restaurantName,
            address: post.restaurantAddress,
            lat: post.lat,
            lng: post.lng
        )
        region = MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: post.lat, longitude: post.lng),
            span: MKCoordinateSpan(latitudeDelta: 0.045, longitudeDelta: 0.045)
        )
        let zoomLevel = min(region.span.latitudeDelta, region.span.longitudeDelta)
        showHeatmap = zoomLevel > zoomThreshold
        calloutDismissRegionAnchor = region
        updateAnnotations()
    }

    /// iOS 17: `onMapCameraChange` context has no `reason`. If the visible region drifts from the callout anchor, treat it as a user-driven move and dismiss.
    func onMapCameraChangeEnded(region visible: MKCoordinateRegion) {
        guard restaurantCallout != nil, let anchor = calloutDismissRegionAnchor else { return }
        if Self.regionsMatchForCalloutDismiss(anchor, visible) { return }
        calloutDismissRegionAnchor = nil
        clearRestaurantCallout()
    }

    private static func regionsMatchForCalloutDismiss(_ a: MKCoordinateRegion, _ b: MKCoordinateRegion) -> Bool {
        let cLat = abs(a.center.latitude - b.center.latitude)
        let cLon = abs(a.center.longitude - b.center.longitude)
        let sLat = abs(a.span.latitudeDelta - b.span.latitudeDelta)
        let sLon = abs(a.span.longitudeDelta - b.span.longitudeDelta)
        return cLat < 0.0002 && cLon < 0.0002 && sLat < 0.0025 && sLon < 0.0025
    }

    func clearRestaurantCallout() {
        restaurantCallout = nil
        calloutDismissRegionAnchor = nil
    }

    var mapAnnotations: [MapAnnotationItem] {
        var items = pins.map { MapAnnotationItem.feed($0) }
        if let c = restaurantCallout {
            items.append(.callout(c))
        }
        return items
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
                id: post.id,
                restaurantId: post.restaurantId,
                restaurantName: post.restaurantName,
                coordinate: CLLocationCoordinate2D(latitude: post.lat, longitude: post.lng),
                isHeat: showHeatmap
            )
        }
    }
}

struct MapPin: Identifiable {
    let id: String
    let restaurantId: String
    let restaurantName: String
    let coordinate: CLLocationCoordinate2D
    let isHeat: Bool
}

struct MapRestaurantCallout: Equatable {
    let name: String
    let address: String?
    let lat: Double
    let lng: Double
}

enum MapAnnotationItem: Identifiable {
    case feed(MapPin)
    case callout(MapRestaurantCallout)

    var id: String {
        switch self {
        case .feed(let pin): return pin.id
        case .callout: return "__bigback_callout__"
        }
    }

    var coordinate: CLLocationCoordinate2D {
        switch self {
        case .feed(let pin): return pin.coordinate
        case .callout(let c): return CLLocationCoordinate2D(latitude: c.lat, longitude: c.lng)
        }
    }
}
