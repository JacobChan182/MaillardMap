import SwiftUI

struct FriendsView: View {
    @EnvironmentObject private var auth: AuthViewModel
    @StateObject private var vm: FriendsViewModel
    /// Pushes `UserPostsView` without a `NavigationLink` in the row (avoids List disclosure chevrons next to the avatar).
    @State private var profileUserId: String?

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
            Section("Find Friends") {
                TextField("Search by username", text: $vm.searchQuery)
                    .onChange(of: vm.searchQuery) { _, _ in
                        vm.scheduleSearchUsers()
                    }

                if vm.trimmedFindFriendsQuery.isEmpty {
                    Text("Type a username to search")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                } else if let err = vm.findFriendsSearchError, !err.isEmpty, vm.searchResults.isEmpty, !vm.isSearchingUsers {
                    Text(err)
                        .font(.subheadline)
                        .foregroundStyle(.red)
                } else if vm.searchResults.isEmpty && !vm.isSearchingUsers {
                    Text(vm.findFriendsAllExcluded
                         ? "Everyone matching is already a friend or has a pending request"
                         : "No users match")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                ForEach(vm.searchResults) { user in
                    HStack(alignment: .center, spacing: 12) {
                        Button {
                            profileUserId = user.id
                        } label: {
                            HStack(alignment: .center, spacing: 12) {
                                ProfileAvatarView(
                                    url: user.avatarUrl,
                                    name: userListTitle(user),
                                    size: 36
                                )
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(userListTitle(user))
                                        .font(.headline)
                                        .foregroundStyle(.primary)
                                    Text("@\(user.username)")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                .multilineTextAlignment(.leading)
                            }
                        }
                        .buttonStyle(.plain)
                        Spacer(minLength: 8)
                        Button("Add") {
                            Task { await vm.sendFriendRequest(userId: user.id) }
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.orange)
                    }
                }
            }

            if !vm.pendingRequests.isEmpty {
                Section("Friend Requests") {
                    ForEach(vm.pendingRequests) { req in
                        HStack(alignment: .center, spacing: 8) {
                            Text("Request from \(req.friendDisplayName ?? req.friendUsername ?? req.friendId)")
                                .font(.headline)
                                .frame(maxWidth: .infinity, alignment: .leading)
                            Button("Decline", role: .cancel) {
                                Task { await vm.removeFriend(friendId: req.friendId) }
                            }
                            .buttonStyle(.bordered)
                            Button("Accept") {
                                Task { await vm.acceptRequest(friendId: req.friendId) }
                            }
                            .buttonStyle(.borderedProminent)
                            .tint(.orange)
                        }
                    }
                }
            }

            if !vm.sentRequests.isEmpty {
                Section("Requests sent") {
                    ForEach(vm.sentRequests) { req in
                        HStack(alignment: .center, spacing: 12) {
                            Button {
                                profileUserId = req.friendId
                            } label: {
                                HStack(alignment: .center, spacing: 12) {
                                    ProfileAvatarView(
                                        url: req.friendAvatarUrl,
                                        name: friendListTitle(req),
                                        size: 36
                                    )
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(friendListTitle(req))
                                            .font(.headline)
                                            .foregroundStyle(.primary)
                                        if let u = req.friendUsername {
                                            Text("@\(u)")
                                                .font(.caption)
                                                .foregroundStyle(.secondary)
                                        }
                                        Text("Waiting for response")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                    .multilineTextAlignment(.leading)
                                }
                            }
                            .buttonStyle(.plain)
                            Spacer(minLength: 8)
                            Button("Revoke") {
                                Task { await vm.removeFriend(friendId: req.friendId) }
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                        }
                    }
                }
            }

            // Friends
            Section {
                if !vm.friends.isEmpty {
                    TextField("Search friends", text: $vm.friendsListSearch)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                }
                if vm.friends.isEmpty {
                    Text("No friends yet")
                        .foregroundStyle(.secondary)
                } else if vm.filteredFriends.isEmpty {
                    Text("No friends match your search")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                ForEach(vm.filteredFriends) { friendship in
                    NavigationLink {
                        UserPostsView(userId: friendship.friendId)
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
                    .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                        Button("Remove", role: .destructive) {
                            Task { await vm.removeFriend(friendId: friendship.friendId) }
                        }
                    }
                }
            } header: {
                Text("Friends (\(vm.friends.count))")
            }
        }
        .listStyle(.insetGrouped)
        .navigationDestination(item: $profileUserId) { userId in
            UserPostsView(userId: userId)
        }
        .task {
            vm.currentUserId = auth.currentUser?.id
            await vm.loadFriends()
        }
        .onChange(of: auth.currentUser?.id) { _, id in
            vm.currentUserId = id
            vm.reapplyFindFriendsSearchFilter()
        }
        .overlay {
            if vm.isSearchingUsers && !vm.trimmedFindFriendsQuery.isEmpty {
                ProgressView()
            }
        }
    }
}
