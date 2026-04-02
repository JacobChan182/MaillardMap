import Foundation

struct AppNotification: Identifiable, Codable, Equatable {
    let id: String
    let type: Kind
    let createdAt: String
    let actorId: String
    let actorUsername: String
    let actorDisplayName: String?
    let actorAvatarUrl: String?
    let postId: String?
    let commentId: String?
    let previewText: String?
    let restaurantId: String?

    enum Kind: String, Codable {
        case friendRequest = "friend_request"
        case friendAccept = "friend_accept"
        case like
        case comment
        case reply
        case mention
        case restaurantShare = "restaurant_share"
    }
}
