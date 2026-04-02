import Foundation

@MainActor
final class BlendViewModel: ObservableObject {
    @Published var availableFriends: [Friendship] = []
    @Published var selectedFriendIds: Set<String> = []
    @Published var blendResult: BlendResult?
    @Published var isLoading = false
    @Published var errorMessage: String?

    private let api: APIClient
    private let currentUserId: String

    init(api: APIClient = .live(), currentUserId: String) {
        self.api = api
        self.currentUserId = currentUserId
    }

    func loadFriends() async {
        do {
            availableFriends = try await api.getFriendsList().filter { $0.status == "accepted" }
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func blend() async {
        var ids = selectedFriendIds
        ids.insert(currentUserId)
        let userIds = Array(ids)

        guard userIds.count >= 1 else {
            errorMessage = "Select at least one person"
            return
        }

        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            let result = try await api.blendTastes(userIds: userIds)
            blendResult = result
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    var recommendations: [ScoredRestaurant] { blendResult?.restaurants ?? [] }
}
