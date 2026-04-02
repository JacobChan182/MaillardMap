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

    func submitComment(postId: String) async {
        guard !newCommentText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        isSubmitting = true
        defer { isSubmitting = false }
        do {
            let comment = try await api.addComment(postId: postId, text: newCommentText.trimmingCharacters(in: .whitespacesAndNewlines))
            comments.append(comment)
            newCommentText = ""
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
