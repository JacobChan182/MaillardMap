import SwiftUI

struct UserPostsView: View {
    @EnvironmentObject private var auth: AuthViewModel
    @EnvironmentObject private var mapVM: MapViewModel
    @EnvironmentObject private var tabRouter: TabRouter
    @StateObject private var vm: UserPostsViewModel
    @State private var showShareRestaurantPicker = false
    @State private var shareRestaurantError: String?

    init(userId: String) {
        _vm = StateObject(wrappedValue: UserPostsViewModel(userId: userId))
    }

    private func profileDisplayName(_ user: User) -> String {
        let n = user.displayName?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return n.isEmpty ? user.username : n
    }

    private var navigationTagTitle: String {
        if let u = vm.user { return "@\(u.username)" }
        return "Profile"
    }

    var body: some View {
        Group {
            if vm.isLoading {
                ProgressView()
            } else {
                ScrollView {
                    LazyVStack(spacing: 12) {
                        if let err = vm.errorMessage {
                            Text(err)
                                .font(.footnote)
                                .foregroundStyle(.red)
                        }
                        if let user = vm.user {
                            let name = profileDisplayName(user)
                            let bioText = user.bio?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                            VStack(spacing: 8) {
                                ProfileAvatarView(url: user.avatarUrl, name: name, size: 64)
                                Text(name)
                                    .font(.title3.weight(.semibold))
                                if bioText.isEmpty {
                                    Text("No bio yet")
                                        .font(.subheadline)
                                        .foregroundStyle(.tertiary)
                                } else {
                                    Text(bioText)
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                        .multilineTextAlignment(.center)
                                        .frame(maxWidth: .infinity)
                                }
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                        }
                        ForEach(vm.posts) { post in
                            PostCardView(
                                post: post,
                                onLike: { postId in await vm.likePost(postId: postId) },
                                onRestaurantTap: {
                                    mapVM.focusRestaurantFromPost(post)
                                    tabRouter.openMap()
                                }
                            )
                        }
                        if vm.posts.isEmpty {
                            ContentUnavailableView(
                                "No posts yet",
                                systemImage: "doc.text"
                            )
                        }
                    }
                    .padding()
                }
                .refreshable { await vm.loadPosts() }
            }
        }
        .navigationTitle(navigationTagTitle)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if let me = auth.currentUser?.id, me != vm.userId {
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Button("Send Restaurant") {
                            showShareRestaurantPicker = true
                        }
                    } label: {
                        Image(systemName: "line.3.horizontal")
                    }
                    .accessibilityLabel("Profile menu")
                }
            }
        }
        .sheet(isPresented: $showShareRestaurantPicker) {
            NavigationStack {
                RestaurantPickerSheet { restaurant in
                    showShareRestaurantPicker = false
                    Task {
                        await sendSharedRestaurant(restaurantId: restaurant.id)
                    }
                }
                .environmentObject(mapVM)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") {
                            showShareRestaurantPicker = false
                        }
                    }
                }
            }
        }
        .alert("Could not send", isPresented: Binding(
            get: { shareRestaurantError != nil },
            set: { if !$0 { shareRestaurantError = nil } }
        )) {
            Button("OK") { shareRestaurantError = nil }
        } message: {
            Text(shareRestaurantError ?? "")
        }
        .task { await vm.loadPosts() }
    }

    private func sendSharedRestaurant(restaurantId: String) async {
        shareRestaurantError = nil
        do {
            try await auth.api.shareRestaurant(recipientId: vm.userId, restaurantId: restaurantId)
        } catch {
            shareRestaurantError = error.localizedDescription
        }
    }
}
