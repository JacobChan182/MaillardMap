import Foundation

@MainActor
final class FriendsViewModel: ObservableObject {
    @Published var friends: [Friendship] = []
    @Published var searchResults: [User] = []
    @Published var searchQuery = ""
    @Published var errorMessage: String?
    @Published var isLoading = false
    @Published var pendingRequests: [Friendship] = []

    private let api: APIClient
    private let currentUserId: String

    init(api: APIClient = .live(), currentUserId: String) {
        self.api = api
        self.currentUserId = currentUserId
    }

    func loadFriends() async {
        isLoading = true
        defer { isLoading = false }
        do {
            let list = try await api.getFriendsList()
            friends = list.filter { $0.status == .accepted }
            pendingRequests = list.filter { $0.status == .pending }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func searchUsers() async {
        guard !searchQuery.isEmpty else {
            searchResults = []
            return
        }
        isLoading = true
        do {
            searchResults = try await api.searchUsers(query: searchQuery)
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    func sendFriendRequest(userId: String) async {
        do {
            try await api.sendFriendRequest(friendId: userId)
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func acceptRequest(requestId: String) async {
        do {
            try await api.acceptFriend(requestId: requestId)
            await loadFriends()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
