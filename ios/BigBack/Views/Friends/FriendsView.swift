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

            Section("Find Friends") {
                TextField("Search by username", text: $vm.searchQuery)
                    .onChange(of: vm.searchQuery) { _, _ in
                        Task { await vm.searchUsers() }
                    }

                if !vm.sentRequests.isEmpty {
                    Text("Requests sent")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .listRowInsets(EdgeInsets(top: 8, leading: 0, bottom: 4, trailing: 0))
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                    ForEach(vm.sentRequests) { req in
                        HStack {
                            ProfileAvatarView(
                                url: req.friendAvatarUrl,
                                name: friendListTitle(req),
                                size: 36
                            )
                            VStack(alignment: .leading, spacing: 2) {
                                Text(friendListTitle(req))
                                    .font(.headline)
                                if let u = req.friendUsername {
                                    Text("@\(u)")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                Text("Waiting for response")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Button("Revoke") {
                                Task { await vm.removeFriend(friendId: req.friendId) }
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                        }
                    }
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
                            searchActionView(for: user)
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
                    .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                        Button("Remove", role: .destructive) {
                            Task { await vm.removeFriend(friendId: friendship.friendId) }
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

    @ViewBuilder
    private func searchActionView(for user: User) -> some View {
        if vm.friends.contains(where: { $0.friendId == user.id }) {
            HStack(spacing: 8) {
                Text("Friends")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Button("Remove") {
                    Task { await vm.removeFriend(friendId: user.id) }
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .tint(.red)
            }
        } else if vm.pendingRequests.contains(where: { $0.friendId == user.id }) {
            Text("Sent you a request")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.trailing)
        } else if vm.sentRequests.contains(where: { $0.friendId == user.id }) {
            HStack(spacing: 8) {
                Label("Request sent", systemImage: "checkmark.circle.fill")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Button("Remove") {
                    Task { await vm.removeFriend(friendId: user.id) }
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
        } else {
            Button("Add") {
                Task { await vm.sendFriendRequest(userId: user.id) }
            }
            .buttonStyle(.borderedProminent)
            .tint(.orange)
        }
    }
}
