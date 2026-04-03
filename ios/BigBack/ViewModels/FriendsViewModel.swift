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
    /// Find Friends `users/search` failure only (not cleared by `loadFriends`).
    @Published var findFriendsSearchError: String?
    /// Loading the friends/pending/sent lists (not the username search).
    @Published var isLoadingFriends = false
    /// In-flight `users/search` request (empty states, stale-result phase).
    @Published var isSearchingUsers = false

    /// Excludes self from Find Friends results when set.
    var currentUserId: String?

    private var lastRawSearchResults: [User] = []

    /// Normalized text used for `users/search` (trim + drop leading `@`).
    var trimmedFindFriendsQuery: String {
        let t = searchQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        if t.hasPrefix("@") {
            return String(t.dropFirst()).trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return t
    }

    private var trimmedSearchQuery: String { trimmedFindFriendsQuery }

    /// Find Friends query returned users, but all are already friends, pending, or you.
    var findFriendsAllExcluded: Bool {
        !trimmedSearchQuery.isEmpty && !lastRawSearchResults.isEmpty && searchResults.isEmpty && !isSearchingUsers
    }

    private let api: APIClient
    private var userSearchDebounceTask: Task<Void, Never>?

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
        if trimmedSearchQuery.isEmpty {
            searchResults = []
            lastRawSearchResults = []
        } else {
            searchResults = applyFindFriendsFilter(lastRawSearchResults)
        }
    }

    func loadFriends() async {
        isLoadingFriends = true
        defer { isLoadingFriends = false }
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

    /// Waits for a typing pause before calling the backend.
    func scheduleSearchUsers(delayNanoseconds: UInt64 = 400_000_000) {
        userSearchDebounceTask?.cancel()
        let q = trimmedSearchQuery
        if q.isEmpty {
            searchResults = []
            lastRawSearchResults = []
            findFriendsSearchError = nil
            return
        }
        userSearchDebounceTask = Task { @MainActor in
            do {
                try await Task.sleep(nanoseconds: delayNanoseconds)
            } catch {
                return
            }
            guard !Task.isCancelled else { return }
            await self.performSearchUsers()
        }
    }

    /// Immediate search (e.g. after removing a friend so results refresh).
    func searchUsers() async {
        userSearchDebounceTask?.cancel()
        await performSearchUsers()
    }

    private func performSearchUsers() async {
        let q = trimmedSearchQuery
        guard !q.isEmpty else {
            searchResults = []
            lastRawSearchResults = []
            findFriendsSearchError = nil
            return
        }
        isSearchingUsers = true
        defer { isSearchingUsers = false }
        do {
            lastRawSearchResults = try await api.searchUsers(query: q)
            searchResults = applyFindFriendsFilter(lastRawSearchResults)
            findFriendsSearchError = nil
        } catch {
            findFriendsSearchError = error.localizedDescription
            lastRawSearchResults = []
            searchResults = []
        }
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
