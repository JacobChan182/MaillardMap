import Foundation

@MainActor
final class BlendViewModel: ObservableObject {
    @Published var availableFriends: [Friendship] = []
    @Published var selectedFriendIds: Set<String> = []
    @Published var recommendations: [BlendRecommendation] = []
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
            availableFriends = try await api.getFriendsList().filter { $0.status == .accepted }
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
            recommendations = try await api.blendTastes(userIds: userIds)
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
