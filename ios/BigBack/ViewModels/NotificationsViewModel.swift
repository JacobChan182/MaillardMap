import Foundation

@MainActor
final class NotificationsViewModel: ObservableObject {
    @Published var items: [AppNotification] = []
    @Published var errorMessage: String?
    @Published var isLoading = false

    private let api: APIClient

    init(api: APIClient = .live()) {
        self.api = api
    }

    func load() async {
        isLoading = true
        defer { isLoading = false }
        do {
            items = try await api.getNotifications()
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func acceptFriendRequest(actorId: String) async {
        do {
            try await api.acceptFriendRequest(friendId: actorId)
            items.removeAll { $0.type == .friendRequest && $0.actorId == actorId }
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
