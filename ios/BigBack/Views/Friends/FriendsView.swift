import SwiftUI

struct FriendsView: View {
    @StateObject private var vm: FriendsViewModel
    @State private var isSearching = false

    init(currentUserId: String) {
        _vm = StateObject(wrappedValue: FriendsViewModel(currentUserId: currentUserId))
    }

    var body: some View {
        List {
            // Pending requests
            if !vm.pendingRequests.isEmpty {
                Section("Friend Requests") {
                    ForEach(vm.pendingRequests) { req in
                        HStack {
                            Text("Request from \(req.friendId)")
                                .font(.headline)
                            Spacer()
                            Button("Accept") {
                                Task { await vm.acceptRequest(requestId: req.id) }
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
                            Text(user.username)
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
                        Label("Friend", systemImage: "person.bubble.fill")
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
