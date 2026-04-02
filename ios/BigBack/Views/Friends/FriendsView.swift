import SwiftUI

struct FriendsView: View {
    @StateObject private var vm: FriendsViewModel
    @State private var isSearching = false

    init() {
        _vm = StateObject(wrappedValue: FriendsViewModel())
    }

    private func userListTitle(_ u: User) -> String {
        let n = u.displayName?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return n.isEmpty ? u.username : n
    }

    private func friendListTitle(_ f: Friendship) -> String {
        let n = f.friendDisplayName?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return n.isEmpty ? (f.friendUsername ?? f.friendId) : n
    }

    var body: some View {
        List {
            // Pending requests
            if !vm.pendingRequests.isEmpty {
                Section("Friend Requests") {
                    ForEach(vm.pendingRequests) { req in
                        HStack {
                            Text("Request from \(req.friendDisplayName ?? req.friendUsername ?? req.friendId)")
                                .font(.headline)
                            Spacer()
                            Button("Accept") {
                                Task { await vm.acceptRequest(friendId: req.friendId) }
                            }
                            .buttonStyle(.borderedProminent)
                            .tint(.orange)
                        }
                    }
                }
            }

            // Search
            Section("Find Friends") {
                TextField("Search by username", text: $vm.searchQuery)
                    .onChange(of: vm.searchQuery) { _, _ in
                        Task { await vm.searchUsers() }
                    }

                if !vm.searchResults.isEmpty {
                    ForEach(vm.searchResults) { user in
                        HStack {
                            ProfileAvatarView(url: user.avatarUrl, name: userListTitle(user), size: 36)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(userListTitle(user))
                                    .font(.headline)
                                Text("@\(user.username)")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Button("Add") {
                                Task { await vm.sendFriendRequest(userId: user.id) }
                            }
                            .buttonStyle(.borderedProminent)
                            .tint(.orange)
                        }
                    }
                }
            }

            // Friends
            Section("Friends (\(vm.friends.count))") {
                if vm.friends.isEmpty {
                    Text("No friends yet")
                        .foregroundStyle(.secondary)
                }
                ForEach(vm.friends) { friendship in
                    NavigationLink {
                        UserPostsView(userId: friendship.friendId)
                            .navigationTitle("Posts")
                    } label: {
                        HStack {
                            ProfileAvatarView(
                                url: friendship.friendAvatarUrl,
                                name: friendListTitle(friendship),
                                size: 36
                            )
                            VStack(alignment: .leading, spacing: 2) {
                                Text(friendListTitle(friendship))
                                if let u = friendship.friendUsername {
                                    Text("@\(u)")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .task { await vm.loadFriends() }
        .overlay {
            if vm.isLoading && !vm.searchQuery.isEmpty {
                ProgressView()
            }
        }
    }
}
