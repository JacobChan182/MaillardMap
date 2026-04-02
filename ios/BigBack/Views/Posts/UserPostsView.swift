import SwiftUI

struct UserPostsView: View {
    @EnvironmentObject private var mapVM: MapViewModel
    @EnvironmentObject private var tabRouter: TabRouter
    @StateObject private var vm: UserPostsViewModel

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
        .task { await vm.loadPosts() }
    }
}
