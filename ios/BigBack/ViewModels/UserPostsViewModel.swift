import Foundation

@MainActor
final class UserPostsViewModel: ObservableObject {
    @Published var posts: [Post] = []
    @Published var errorMessage: String?
    @Published var isLoading = false
    @Published var user: User?

    private let api: APIClient
    let userId: String

    init(api: APIClient = .live(), userId: String) {
        self.api = api
        self.userId = userId
    }

    func loadPosts() async {
        isLoading = true
        defer { isLoading = false }
        do {
            posts = try await api.getUserPosts(userId: userId)
            user = try await api.getUser(id: userId)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func likePost(postId: String) async {
        do {
            _ = try await api.likePost(postId: postId)
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
