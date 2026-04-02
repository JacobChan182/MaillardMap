import Foundation

@MainActor
final class UserPostsViewModel: ObservableObject {
    @Published var posts: [Post] = []
    /// Server withheld posts (private profile, viewer not a friend).
    @Published var postsHidden = false
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
            async let userTask = api.getUser(id: userId)
            async let postsTask = api.getUserPosts(userId: userId)
            let loadedUser = try await userTask
            let (loadedPosts, hidden) = try await postsTask
            user = loadedUser
            posts = loadedPosts
            postsHidden = hidden
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
