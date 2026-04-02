import Foundation

struct Friendship: Identifiable, Codable, Equatable {
    let id: String
    let friendId: String
    let friendUsername: String?
    let friendDisplayName: String?
    let friendAvatarUrl: String?
    let status: String
    let createdAt: String
}
