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

    @discardableResult
    func likePost(postId: String) async -> Post? {
        do {
            let liked = try await api.likePost(postId: postId)
            if let idx = posts.firstIndex(where: { $0.id == postId }) {
                var p = posts[idx]
                p = Post(
                    id: p.id, userId: p.userId, username: p.username,
                    displayName: p.displayName, avatarUrl: p.avatarUrl,
                    restaurantId: p.restaurantId, restaurantName: p.restaurantName,
                    restaurantAddress: p.restaurantAddress,
                    lat: p.lat, lng: p.lng, comment: p.comment,
                    rating: p.rating,
                    photos: p.photos, liked: liked,
                    likeCount: liked ? p.likeCount + 1 : max(0, p.likeCount - 1),
                    commentCount: p.commentCount,
                    createdAt: p.createdAt
                )
                posts[idx] = p
                errorMessage = nil
                return p
            }
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
        return nil
    }
}
