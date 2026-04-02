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
    /// Temporary map callout from a post’s restaurant chip; cleared when the user pans/zooms the map.
    @Published var restaurantCallout: MapRestaurantCallout?
    /// Region snapshot when the callout was shown (iOS 17 has no `MapCameraUpdateContext.reason`; compare camera to this to detect user moves).
    private var calloutDismissRegionAnchor: MKCoordinateRegion?
    /// After `focusRestaurantFromPost`, MapKit emits `onMapCameraChange` ends that don’t numerically match our anchor; skip dismissing for a few events so the white card can appear.
    private var calloutDismissSkipCameraEndsRemaining = 0
    /// When the user moves the map off the callout anchor, dismiss the card after 0.1s (debounced per gesture end).
    private var calloutDelayedDismissTask: Task<Void, Never>?
    /// After programmatic camera moves (post/search deep link), align dismiss tracking with `showCalloutForMapPin` once the map settles.
    private var calloutDismissAlignTask: Task<Void, Never>?
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
            // Center on first known user location only once; later fixes must not override manual / restaurant focus.
            if !hasCenteredOnUserLocation {
                region = MKCoordinateRegion(
                    center: coordinate,
                    span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
                )
                hasCenteredOnUserLocation = true
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

    /// After programmatic fly-ins, MapKit emits extra camera-end callbacks. When those settle, use the same dismiss baseline as `showCalloutForMapPin` so pan/zoom clears the card and marker like reviewed venues.
    private func scheduleCalloutDismissAlignLikeMapPin(restaurantId: String) {
        calloutDismissAlignTask?.cancel()
        calloutDismissAlignTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 600_000_000)
            guard !Task.isCancelled else { return }
            guard self.restaurantCallout?.restaurantId == restaurantId else { return }
            self.calloutDismissRegionAnchor = self.region
            self.calloutDismissSkipCameraEndsRemaining = 0
        }
    }

    /// Center map and show the white venue callout (same behavior as a post’s restaurant link).
    private func focusRestaurantOnMap(
        restaurantId: String,
        name: String,
        address: String?,
        lat: Double,
        lng: Double,
        useTemporaryGrayPin: Bool = false,
    ) {
        calloutInterruptedDismissTasks()
        restaurantCallout = MapRestaurantCallout(
            restaurantId: restaurantId,
            name: name,
            address: address,
            lat: lat,
            lng: lng,
            useTemporaryGrayPin: useTemporaryGrayPin
        )
        region = MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: lat, longitude: lng),
            span: MKCoordinateSpan(latitudeDelta: 0.045, longitudeDelta: 0.045)
        )
        let zoomLevel = min(region.span.latitudeDelta, region.span.longitudeDelta)
        showHeatmap = zoomLevel > zoomThreshold
        calloutDismissRegionAnchor = region
        calloutDismissSkipCameraEndsRemaining = 3
        hasCenteredOnUserLocation = true
        updateAnnotations()
        scheduleCalloutDismissAlignLikeMapPin(restaurantId: restaurantId)
    }

    /// Feed / post list: jump map here with the white callout pin.
    func focusRestaurantFromPost(_ post: Post) {
        let trimmed = post.restaurantAddress?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        // #region agent log
        #if DEBUG
        AgentMapDebug.log(
            hypothesisId: "H1",
            location: "MapViewModel.focusRestaurantFromPost",
            message: "restaurant chip tap",
            data: [
                "addrFromPostLen": "\(trimmed.count)",
                "restaurantId8": String(post.restaurantId.prefix(8)),
            ]
        )
        #endif
        // #endregion
        focusRestaurantOnMap(
            restaurantId: post.restaurantId,
            name: post.restaurantName,
            address: trimmed.isEmpty ? nil : trimmed,
            lat: post.lat,
            lng: post.lng
        )
        if trimmed.isEmpty {
            Task { await enrichCalloutAddress(restaurantId: post.restaurantId) }
        }
    }

    /// Find Restaurants search row: same map + callout as a post link; gray pin until we know friends/you have posts here.
    func focusRestaurantFromSearch(_ restaurant: Restaurant) {
        let trimmed = restaurant.address?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let rid = restaurant.id
        focusRestaurantOnMap(
            restaurantId: rid,
            name: restaurant.name,
            address: trimmed.isEmpty ? nil : trimmed,
            lat: restaurant.lat,
            lng: restaurant.lng,
            useTemporaryGrayPin: true
        )
        if trimmed.isEmpty {
            Task { await enrichCalloutAddress(restaurantId: rid) }
        }

        Task {
            let hasPostsInFeedScope: Bool
            do {
                let payload = try await api.getPostsForRestaurant(restaurantId: rid)
                hasPostsInFeedScope = !payload.posts.isEmpty
            } catch {
                hasPostsInFeedScope = false
            }
            await MainActor.run {
                guard let c = restaurantCallout, c.restaurantId == rid else { return }
                restaurantCallout = MapRestaurantCallout(
                    restaurantId: c.restaurantId,
                    name: c.name,
                    address: c.address,
                    lat: c.lat,
                    lng: c.lng,
                    useTemporaryGrayPin: !hasPostsInFeedScope
                )
                scheduleCalloutDismissAlignLikeMapPin(restaurantId: rid)
            }
        }
    }

    /// Shared-restaurant notification: load venue, then same gray/orange pin + card as search.
    func focusRestaurantFromShare(restaurantId: String) async -> Bool {
        do {
            let r = try await api.getRestaurant(id: restaurantId)
            focusRestaurantFromSearch(r)
            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }

    /// Map pin tap: show the white card above the venue; tap the card to open restaurant posts.
    func showCalloutForMapPin(restaurantId: String, name: String, coordinate: CLLocationCoordinate2D) {
        calloutInterruptedDismissTasks()
        restaurantCallout = MapRestaurantCallout(
            restaurantId: restaurantId,
            name: name,
            address: nil,
            lat: coordinate.latitude,
            lng: coordinate.longitude
        )
        calloutDismissRegionAnchor = region
        calloutDismissSkipCameraEndsRemaining = 0
        hasCenteredOnUserLocation = true
        updateAnnotations()
        Task { await enrichCalloutAddress(restaurantId: restaurantId) }
    }

    /// Feed JSON often omits address when the DB row was created before we stored it; fill from `GET /restaurants/:id`.
    private func enrichCalloutAddress(restaurantId: String) async {
        do {
            let r = try await api.getRestaurant(id: restaurantId)
            let addr = r.address?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            guard !addr.isEmpty else {
                // #region agent log
                #if DEBUG
                AgentMapDebug.log(
                    hypothesisId: "H5",
                    location: "MapViewModel.enrichCalloutAddress",
                    message: "no address from getRestaurant",
                    data: ["restaurantId8": String(restaurantId.prefix(8))]
                )
                #endif
                // #endregion
                return
            }
            guard let c = restaurantCallout, c.restaurantId == restaurantId else { return }
            restaurantCallout = MapRestaurantCallout(
                restaurantId: c.restaurantId,
                name: c.name,
                address: addr,
                lat: c.lat,
                lng: c.lng,
                useTemporaryGrayPin: c.useTemporaryGrayPin
            )
            // #region agent log
            #if DEBUG
            AgentMapDebug.log(
                hypothesisId: "H5",
                location: "MapViewModel.enrichCalloutAddress",
                message: "callout address enriched",
                data: ["addrLen": "\(addr.count)"]
            )
            #endif
            // #endregion
        } catch {
            // #region agent log
            #if DEBUG
            AgentMapDebug.log(
                hypothesisId: "H5",
                location: "MapViewModel.enrichCalloutAddress",
                message: "getRestaurant failed",
                data: ["err": String(describing: type(of: error))]
            )
            #endif
            // #endregion
        }
    }

    /// iOS 17: no `MapCameraUpdateContext.reason`. Programmatic recenter often reports a `visible` region that doesn’t match our anchor numerically, which used to clear the callout instantly; we skip a few `onEnd` callbacks, then compare loosely to detect real pans/zooms.
    func onMapCameraChangeEnded(region visible: MKCoordinateRegion) {
        guard restaurantCallout != nil else { return }
        if calloutDismissSkipCameraEndsRemaining > 0 {
            calloutDismissSkipCameraEndsRemaining -= 1
            calloutDismissRegionAnchor = visible
            calloutDelayedDismissTask?.cancel()
            calloutDelayedDismissTask = nil
            return
        }
        guard let anchor = calloutDismissRegionAnchor else { return }
        if Self.regionsMatchForCalloutDismiss(anchor, visible) {
            calloutDismissRegionAnchor = visible
            calloutDelayedDismissTask?.cancel()
            calloutDelayedDismissTask = nil
            return
        }
        guard let rid = restaurantCallout?.restaurantId else { return }
        calloutDelayedDismissTask?.cancel()
        calloutDelayedDismissTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 100_000_000)
            guard !Task.isCancelled else { return }
            guard let c = restaurantCallout, c.restaurantId == rid else { return }
            // #region agent log
            #if DEBUG
            AgentMapDebug.log(
                hypothesisId: "H6",
                location: "MapViewModel.callout delayed dismiss",
                message: "dismissing callout after user map interaction",
                data: [:]
            )
            #endif
            // #endregion
            clearRestaurantCallout()
        }
    }

    private static func regionsMatchForCalloutDismiss(_ a: MKCoordinateRegion, _ b: MKCoordinateRegion) -> Bool {
        let cLat = abs(a.center.latitude - b.center.latitude)
        let cLon = abs(a.center.longitude - b.center.longitude)
        let sLat = abs(a.span.latitudeDelta - b.span.latitudeDelta)
        let sLon = abs(a.span.longitudeDelta - b.span.longitudeDelta)
        return cLat < 0.001 && cLon < 0.001 && sLat < 0.012 && sLon < 0.012
    }

    func clearRestaurantCallout() {
        calloutInterruptedDismissTasks()
        restaurantCallout = nil
        calloutDismissRegionAnchor = nil
        calloutDismissSkipCameraEndsRemaining = 0
    }

    private func calloutInterruptedDismissTasks() {
        calloutDelayedDismissTask?.cancel()
        calloutDelayedDismissTask = nil
        calloutDismissAlignTask?.cancel()
        calloutDismissAlignTask = nil
    }

    var mapAnnotations: [MapAnnotationItem] {
        var items = pins.map { MapAnnotationItem.feed($0) }
        if let c = restaurantCallout {
            if c.useTemporaryGrayPin {
                items.append(
                    .temporaryGrayPin(
                        restaurantId: c.restaurantId,
                        coordinate: CLLocationCoordinate2D(latitude: c.lat, longitude: c.lng)
                    )
                )
            }
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
    let restaurantId: String
    let name: String
    let address: String?
    let lat: Double
    let lng: Double
    /// Gray mappin from Find Restaurants when there are no posts (friends + you) at this venue yet.
    let useTemporaryGrayPin: Bool

    init(
        restaurantId: String,
        name: String,
        address: String?,
        lat: Double,
        lng: Double,
        useTemporaryGrayPin: Bool = false,
    ) {
        self.restaurantId = restaurantId
        self.name = name
        self.address = address
        self.lat = lat
        self.lng = lng
        self.useTemporaryGrayPin = useTemporaryGrayPin
    }
}

enum MapAnnotationItem: Identifiable {
    case feed(MapPin)
    case temporaryGrayPin(restaurantId: String, coordinate: CLLocationCoordinate2D)
    case callout(MapRestaurantCallout)

    var id: String {
        switch self {
        case .feed(let pin): return pin.id
        case .temporaryGrayPin(let rid, _): return "__gray_\(rid)"
        case .callout: return "__bigback_callout__"
        }
    }

    var coordinate: CLLocationCoordinate2D {
        switch self {
        case .feed(let pin): return pin.coordinate
        case .temporaryGrayPin(_, let coordinate): return coordinate
        case .callout(let c): return CLLocationCoordinate2D(latitude: c.lat, longitude: c.lng)
        }
    }
}

#if DEBUG
private enum AgentMapDebug {
    private static let ingestURL = URL(string: "http://127.0.0.1:7707/ingest/d9fc1c80-35fe-4ab7-aba1-28f71cd71200")!

    static func log(hypothesisId: String, location: String, message: String, data: [String: String] = [:]) {
        var payload: [String: Any] = [
            "sessionId": "38d789",
            "hypothesisId": hypothesisId,
            "location": location,
            "message": message,
            "timestamp": Int(Date().timeIntervalSince1970 * 1000),
        ]
        if !data.isEmpty { payload["data"] = data }
        guard JSONSerialization.isValidJSONObject(payload),
              let body = try? JSONSerialization.data(withJSONObject: payload) else { return }
        var req = URLRequest(url: ingestURL)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue("38d789", forHTTPHeaderField: "X-Debug-Session-Id")
        req.httpBody = body
        Task.detached(priority: .utility) {
            _ = try? await URLSession.shared.data(for: req)
        }
    }
}
#endif
