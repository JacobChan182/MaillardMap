import Foundation

@MainActor
final class RestaurantPostsViewModel: ObservableObject {
    @Published var posts: [Post] = []
    @Published var errorMessage: String?
    @Published var isLoading = false

    let restaurantId: String
    private let api: APIClient

    init(restaurantId: String, api: APIClient = .live()) {
        self.restaurantId = restaurantId
        self.api = api
    }

    func load() async {
        isLoading = true
        defer { isLoading = false }
        do {
            posts = try await api.getPostsForRestaurant(restaurantId: restaurantId)
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
