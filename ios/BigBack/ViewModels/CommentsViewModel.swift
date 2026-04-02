import Foundation

@MainActor
final class CommentsViewModel: ObservableObject {
    @Published var comments: [Comment] = []
    @Published var newCommentText = ""
    @Published var isLoading = false
    @Published var isSubmitting = false
    @Published var errorMessage: String?

    private let api: APIClient

    init(api: APIClient = .live()) {
        self.api = api
    }

    func loadComments(postId: String) async {
        isLoading = true
        defer { isLoading = false }
        do {
            comments = try await api.getComments(postId: postId)
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    /// - Returns: `true` if the comment was posted and list refreshed.
    @discardableResult
    func submitComment(postId: String, parentCommentId: String?) async -> Bool {
        let trimmed = newCommentText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return false }
        isSubmitting = true
        defer { isSubmitting = false }
        do {
            _ = try await api.addComment(postId: postId, text: trimmed, parentCommentId: parentCommentId)
            await loadComments(postId: postId)
            newCommentText = ""
            errorMessage = nil
            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }
}
