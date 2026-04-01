import Foundation

struct Friendship: Identifiable, Codable {
    let id: String
    let userId: String
    let friendId: String
    let status: FriendshipStatus
    let createdAt: String?
}

enum FriendshipStatus: String, Codable {
    case pending
    case accepted
}
