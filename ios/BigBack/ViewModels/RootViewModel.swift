import Foundation

@MainActor
final class RootViewModel: ObservableObject {
    @Published private(set) var statusText: String = "Not connected"

    private let api: APIClient

    init(api: APIClient = .live()) {
        self.api = api
    }

    func pingHealth() async {
        statusText = "Checking…"
        do {
            let health = try await api.getHealth()
            statusText = "OK (\(health.service))"
        } catch {
            statusText = "Failed: \(error.localizedDescription)"
        }
    }
}

