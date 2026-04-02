import Foundation

@MainActor
final class FriendsViewModel: ObservableObject {
    @Published var friends: [Friendship] = []
    @Published var pendingRequests: [Friendship] = []
    @Published var sentRequests: [Friendship] = []
    @Published private(set) var searchResults: [User] = []
    @Published var searchQuery = ""
    /// Filters the accepted friends list (username / display name).
    @Published var friendsListSearch = ""
    @Published var errorMessage: String?
    @Published var isLoading = false

    /// Excludes self from Find Friends results when set.
    var currentUserId: String?

    private var lastRawSearchResults: [User] = []

    /// Find Friends query returned users, but all are already friends, pending, or you.
    var findFriendsAllExcluded: Bool {
        !searchQuery.isEmpty && !lastRawSearchResults.isEmpty && searchResults.isEmpty && !isLoading
    }

    private let api: APIClient

    init(api: APIClient = .live()) {
        self.api = api
    }

    var filteredFriends: [Friendship] {
        let q = friendsListSearch.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !q.isEmpty else { return friends }
        return friends.filter { matchesFriendsListQuery($0, query: q) }
    }

    private func matchesFriendsListQuery(_ f: Friendship, query: String) -> Bool {
        if let u = f.friendUsername?.lowercased(), u.contains(query) { return true }
        if let d = f.friendDisplayName?.lowercased(), d.contains(query) { return true }
        return false
    }

    private var excludedFromFindFriends: Set<String> {
        var ids = Set<String>()
        ids.formUnion(friends.map(\.friendId))
        ids.formUnion(pendingRequests.map(\.friendId))
        ids.formUnion(sentRequests.map(\.friendId))
        if let me = currentUserId, !me.isEmpty { ids.insert(me) }
        return ids
    }

    private func applyFindFriendsFilter(_ users: [User]) -> [User] {
        let skip = excludedFromFindFriends
        return users.filter { !skip.contains($0.id) }
    }

    /// Re-filter Find Friends after friendship lists or `currentUserId` change (no new network call).
    func reapplyFindFriendsSearchFilter() {
        if searchQuery.isEmpty {
            searchResults = []
            lastRawSearchResults = []
        } else {
            searchResults = applyFindFriendsFilter(lastRawSearchResults)
        }
    }

    func loadFriends() async {
        isLoading = true
        defer { isLoading = false }
        do {
            let list = try await api.getFriendsList()
            friends = list.filter { $0.status == "accepted" }
            pendingRequests = list.filter { $0.status == "pending" && $0.incomingPending != false }
            sentRequests = list.filter { $0.status == "pending" && $0.incomingPending == false }
            errorMessage = nil
            reapplyFindFriendsSearchFilter()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func searchUsers() async {
        guard !searchQuery.isEmpty else {
            searchResults = []
            lastRawSearchResults = []
            return
        }
        isLoading = true
        do {
            lastRawSearchResults = try await api.searchUsers(query: searchQuery)
            searchResults = applyFindFriendsFilter(lastRawSearchResults)
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    func sendFriendRequest(userId: String) async {
        do {
            try await api.sendFriendRequest(friendId: userId)
            await loadFriends()
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

    func removeFriend(friendId: String) async {
        do {
            try await api.removeFriend(friendId: friendId)
            await loadFriends()
            await searchUsers()
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
