import Foundation

@MainActor
final class NotificationsViewModel: ObservableObject {
    @Published var items: [AppNotification] = []
    @Published var errorMessage: String?
    @Published var isLoading = false

    private let api: APIClient
    private let dismissedDefaultsKey = "dismissedNotificationIds"
    private var dismissedIds: Set<String> {
        get {
            Set(UserDefaults.standard.stringArray(forKey: dismissedDefaultsKey) ?? [])
        }
        set {
            UserDefaults.standard.set(Array(newValue), forKey: dismissedDefaultsKey)
        }
    }

    init(api: APIClient = .live()) {
        self.api = api
    }

    func load() async {
        isLoading = true
        defer { isLoading = false }
        do {
            let dismissed = dismissedIds
            items = try await api.getNotifications().filter { !dismissed.contains($0.id) }
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

    func dismiss(_ item: AppNotification) async {
        var dismissed = dismissedIds
        dismissed.insert(item.id)
        dismissedIds = dismissed
        items.removeAll { $0.id == item.id }
        do {
            try await api.dismissNotification(id: item.id)
            errorMessage = nil
        } catch {
            // Keep the local dismissal so the notification does not pop back in if the API is briefly stale.
            errorMessage = error.localizedDescription
        }
    }
}
