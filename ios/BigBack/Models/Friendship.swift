import Foundation

struct Friendship: Identifiable, Codable, Equatable {
    let id: String
    let friendId: String
    let friendUsername: String?
    let status: String
    let createdAt: String
}
