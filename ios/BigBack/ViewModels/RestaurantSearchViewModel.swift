import Foundation
import CoreLocation

@MainActor
final class RestaurantSearchViewModel: ObservableObject {
    @Published var results: [Restaurant] = []
    @Published var query = ""
    @Published var isLoading = false
    /// True while debounce delay is running (before `performSearch` starts). Keeps UI from showing "no results" prematurely.
    @Published var isAwaitingDebouncedSearch = false
    @Published var errorMessage: String?
    @Published var selectedRestaurant: Restaurant?

    private let api: APIClient
    private var debounceTask: Task<Void, Never>?

    init(api: APIClient = .live()) {
        self.api = api
    }

    /// Debounces keystrokes so Foursquare is not hit on every character.
    func scheduleDebouncedSearch(near coordinate: CLLocationCoordinate2D, delayNanoseconds: UInt64 = 400_000_000) {
        debounceTask?.cancel()
        if query.isEmpty {
            results = []
            errorMessage = nil
            isLoading = false
            isAwaitingDebouncedSearch = false
            return
        }
        isAwaitingDebouncedSearch = true
        debounceTask = Task { @MainActor in
            do {
                try await Task.sleep(nanoseconds: delayNanoseconds)
            } catch {
                return
            }
            guard !Task.isCancelled else { return }
            await self.performSearch(near: coordinate)
        }
    }

    /// Prefer coordinates from the shared `MapViewModel` (`userLocation` or map `region.center`) so search matches what the map shows.
    /// Runs immediately (e.g. map anchor changed, screen appeared with existing query).
    func search(near coordinate: CLLocationCoordinate2D) async {
        debounceTask?.cancel()
        isAwaitingDebouncedSearch = false
        await performSearch(near: coordinate)
    }

    private func performSearch(near coordinate: CLLocationCoordinate2D) async {
        isAwaitingDebouncedSearch = false
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
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
