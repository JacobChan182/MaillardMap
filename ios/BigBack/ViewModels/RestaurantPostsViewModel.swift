import Foundation

@MainActor
final class RestaurantPostsViewModel: ObservableObject {
    @Published var posts: [Post] = []
    @Published var averageRating: Double?
    @Published var ratingCount: Int = 0
    @Published var errorMessage: String?
    @Published var isLoading = false
    @Published var isSaved = false
    @Published var isSaveBusy = false
    @Published var saveError: String?

    let restaurantId: String
    private let api: APIClient

    init(restaurantId: String, api: APIClient = .live()) {
        self.restaurantId = restaurantId
        self.api = api
    }

    func load() async {
        isLoading = true
        defer { isLoading = false }
        let id = restaurantId
        let client = api
        do {
            // Detached so SwiftUI cancelling `.task` / `refreshable` does not cancel URLSession (server saw aborted connections).
            let payload = try await Task.detached(priority: .userInitiated) {
                try await client.getPostsForRestaurant(restaurantId: id)
            }.value
            posts = payload.posts
            averageRating = payload.averageRating
            ratingCount = payload.ratingCount
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }

        await refreshSavedState()
    }

    private func refreshSavedState() async {
        do {
            let saved = try await api.getSavedPlaces()
            isSaved = saved.contains { $0.restaurantId == restaurantId }
            saveError = nil
        } catch {
            isSaved = false
        }
    }

    func toggleSave() async {
        guard !isSaveBusy else { return }
        isSaveBusy = true
        defer { isSaveBusy = false }
        do {
            if isSaved {
                try await api.deleteSavedPlace(restaurantId: restaurantId)
                isSaved = false
            } else {
                _ = try await api.savePlace(restaurantId: restaurantId)
                isSaved = true
            }
            saveError = nil
        } catch {
            saveError = error.localizedDescription
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
