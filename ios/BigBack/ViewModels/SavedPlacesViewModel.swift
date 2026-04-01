import Foundation

@MainActor
final class SavedPlacesViewModel: ObservableObject {
    @Published var savedPlaces: [SavedPlace] = []
    @Published var errorMessage: String?
    @Published var isLoading = false

    private let api: APIClient

    init(api: APIClient = .live()) {
        self.api = api
    }

    func loadPlaces() async {
        isLoading = true
        defer { isLoading = false }
        do {
            savedPlaces = try await api.getSavedPlaces()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func savePlace(restaurantId: String) async {
        do {
            try await api.savePlace(restaurantId: restaurantId)
            await loadPlaces()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func deletePlace(restaurantId: String) async {
        do {
            try await api.deleteSavedPlace(restaurantId: restaurantId)
            savedPlaces.removeAll { $0.restaurantId == restaurantId }
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
