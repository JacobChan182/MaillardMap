import SwiftUI
import UIKit

/// Full-screen post with comments below and a pinned composer.
struct PostDetailView: View {
    @EnvironmentObject private var auth: AuthViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var post: Post
    let onLike: (String) async -> Post?
    var onRestaurantTap: (() -> Void)?
    var onDeleted: (() -> Void)?

    @StateObject private var commentsVM = CommentsViewModel()
    @FocusState private var fieldFocused: Bool
    @State private var replyingTo: Comment?
    @State private var showMentionPicker = false
    @State private var showDeleteConfirm = false
    @State private var isDeleting = false
    @State private var deleteError: String?

    private var isOwnPost: Bool {
        guard let me = auth.currentUser?.id else { return false }
        return post.userId == me
    }

    init(
        post: Post,
        onLike: @escaping (String) async -> Post?,
        onRestaurantTap: (() -> Void)? = nil,
        onDeleted: (() -> Void)? = nil
    ) {
        _post = State(initialValue: post)
        self.onLike = onLike
        self.onRestaurantTap = onRestaurantTap
        self.onDeleted = onDeleted
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
        .toolbar {
            if isOwnPost {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(role: .destructive) {
                        showDeleteConfirm = true
                    } label: {
                        Image(systemName: "trash")
                    }
                    .accessibilityLabel("Delete post")
                    .disabled(isDeleting)
                }
            }
        }
        .confirmationDialog(
            "Delete this post?",
            isPresented: $showDeleteConfirm,
            titleVisibility: .visible
        ) {
            Button("Delete post", role: .destructive) {
                Task { await deletePost() }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This removes the post, photos, likes, and comments. This cannot be undone.")
        }
        .alert(
            "Could not delete post",
            isPresented: Binding(
                get: { deleteError != nil },
                set: { if !$0 { deleteError = nil } }
            )
        ) {
            Button("OK", role: .cancel) { deleteError = nil }
        } message: {
            Text(deleteError ?? "")
        }
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

    private func deletePost() async {
        guard !isDeleting else { return }
        isDeleting = true
        defer { isDeleting = false }
        do {
            try await auth.api.deletePost(id: post.id)
            NotificationCenter.default.post(
                name: .bigBackDidDeletePost,
                object: nil,
                userInfo: ["postId": post.id]
            )
            onDeleted?()
            dismiss()
        } catch {
            deleteError = error.localizedDescription
        }
    }
}
