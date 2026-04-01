import SwiftUI

struct UserPostsView: View {
    @StateObject private var vm: UserPostsViewModel

    init(userId: String) {
        _vm = StateObject(wrappedValue: UserPostsViewModel(userId: userId))
    }

    var body: some View {
        Group {
            if vm.isLoading {
                ProgressView()
            } else {
                ScrollView {
                    LazyVStack(spacing: 12) {
                        if let user = vm.user {
                            Text(user.username)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                        ForEach(vm.posts) { post in
                            PostCardView(post: post) { postId in
                                await vm.likePost(postId: postId)
                            }
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
        .task { await vm.loadPosts() }
    }
}
