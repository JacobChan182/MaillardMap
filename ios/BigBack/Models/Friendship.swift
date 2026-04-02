import Foundation

struct Friendship: Identifiable, Codable, Equatable {
    let id: String
    let friendId: String
    let friendUsername: String?
    let friendDisplayName: String?
    let friendAvatarUrl: String?
    let status: String
    let createdAt: String
    /// `true` = they requested you; `false` = you requested them; `nil` for accepted friendships or older API responses.
    let incomingPending: Bool?
}
