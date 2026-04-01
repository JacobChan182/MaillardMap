import Foundation

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

    func search() async {
        guard !query.isEmpty else {
            results = []
            return
        }
        isLoading = true
        defer { isLoading = false }
        do {
            results = try await api.searchRestaurants(query: query)
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
