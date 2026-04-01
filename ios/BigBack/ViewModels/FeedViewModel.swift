import Foundation

@MainActor
final class FeedViewModel: ObservableObject {
    @Published var posts: [Post] = []
    @Published var errorMessage: String?
    @Published var isLoading = false

    private let api: APIClient

    init(api: APIClient = .live()) {
        self.api = api
    }

    func loadFeed() async {
        isLoading = true
        defer { isLoading = false }
        do {
            posts = try await api.getFeed()
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func likePost(postId: String) async {
        do {
            let liked = try await api.likePost(postId: postId)
            if let idx = posts.firstIndex(where: { $0.id == postId }) {
                var p = posts[idx]
                p = Post(
                    id: p.id, userId: p.userId, username: p.username,
                    restaurantId: p.restaurantId, restaurantName: p.restaurantName,
                    restaurantAddress: p.restaurantAddress,
                    lat: p.lat, lng: p.lng, comment: p.comment,
                    photos: p.photos, liked: liked,
                    likeCount: liked ? p.likeCount + 1 : max(0, p.likeCount - 1),
                    createdAt: p.createdAt
                )
                posts[idx] = p
            }
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
