import Foundation

@MainActor
final class FriendsViewModel: ObservableObject {
    @Published var friends: [Friendship] = []
    @Published var searchResults: [User] = []
    @Published var searchQuery = ""
    @Published var errorMessage: String?
    @Published var isLoading = false

    private let api: APIClient

    init(api: APIClient = .live()) {
        self.api = api
    }

    func loadFriends() async {
        isLoading = true
        defer { isLoading = false }
        do {
            let list = try await api.getFriendsList()
            friends = list
            errorMessage = nil
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
            errorMessage = nil
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

    func acceptRequest(friendId: String) async {
        do {
            try await api.acceptFriendRequest(friendId: friendId)
            await loadFriends()
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
