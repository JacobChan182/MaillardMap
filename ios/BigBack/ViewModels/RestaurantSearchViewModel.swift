import Foundation
import CoreLocation

@MainActor
final class RestaurantSearchViewModel: ObservableObject {
    @Published var results: [Restaurant] = []
    @Published var query = ""
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var selectedRestaurant: Restaurant?

    private let api: APIClient

    init(api: APIClient = .live()) {
        self.api = api
    }

    /// Prefer coordinates from the shared `MapViewModel` (`userLocation` or map `region.center`) so search matches what the map shows.
    func search(near coordinate: CLLocationCoordinate2D) async {
        guard !query.isEmpty else {
            results = []
            return
        }
        isLoading = true
        defer { isLoading = false }
        do {
            results = try await api.searchRestaurants(
                query: query,
                lat: coordinate.latitude,
                lng: coordinate.longitude
            )
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
