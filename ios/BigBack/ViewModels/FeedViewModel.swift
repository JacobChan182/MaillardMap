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
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func likePost(postId: String) async {
        do {
            try await api.likePost(postId: postId)
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
