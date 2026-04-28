import SwiftUI
import UIKit

/// Full-screen post with comments below and a pinned composer.
struct PostDetailView: View {
    @State private var post: Post
    let onLike: (String) async -> Post?
    var onRestaurantTap: (() -> Void)?

    @StateObject private var commentsVM = CommentsViewModel()
    @FocusState private var fieldFocused: Bool
    @State private var replyingTo: Comment?
    @State private var showMentionPicker = false

    init(post: Post, onLike: @escaping (String) async -> Post?, onRestaurantTap: (() -> Void)? = nil) {
        _post = State(initialValue: post)
        self.onLike = onLike
        self.onRestaurantTap = onRestaurantTap
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                PostCardView(
                    post: post,
                    onLike: { id in
                        let u = await onLike(id)
                        if let u { post = u }
                        return u
                    },
                    onRestaurantTap: onRestaurantTap,
                    variant: .detail
                )

                Divider()
                    .padding(.vertical, 12)

                Text("Comments")
                    .font(.title3.weight(.semibold))
                    .padding(.bottom, 4)

                CommentsThreadListContent(
                    comments: commentsVM.comments,
                    isLoading: commentsVM.isLoading,
                    onReply: startReply
                )
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 8)
            .contentShape(Rectangle())
            .onTapGesture {
                fieldFocused = false
                UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
            }
        }
        .scrollDismissesKeyboard(.interactively)
        .simultaneousGesture(
            TapGesture().onEnded {
                fieldFocused = false
            },
            including: .subviews
        )
        .safeAreaInset(edge: .bottom, spacing: 0) {
            CommentsInputPanel(
                vm: commentsVM,
                postId: post.id,
                replyingTo: $replyingTo,
                fieldFocused: $fieldFocused,
                showMentionPicker: $showMentionPicker,
                onCommentPosted: { bumpCommentCount() }
            )
        }
        .dismissKeyboardOnTap()
        .navigationTitle("Post")
        .navigationBarTitleDisplayMode(.inline)
        .task { await commentsVM.loadComments(postId: post.id) }
    }

    private func startReply(to comment: Comment) {
        replyingTo = comment
        fieldFocused = true
    }

    private func bumpCommentCount() {
        post = Post(
            id: post.id, userId: post.userId, username: post.username,
            displayName: post.displayName, avatarUrl: post.avatarUrl,
            restaurantId: post.restaurantId, restaurantName: post.restaurantName,
            restaurantAddress: post.restaurantAddress,
            lat: post.lat, lng: post.lng, comment: post.comment,
            rating: post.rating,
            photos: post.photos, liked: post.liked,
            likeCount: post.likeCount,
            commentCount: post.commentCount + 1,
            createdAt: post.createdAt
        )
    }
}
