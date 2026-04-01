import Foundation

struct Post: Identifiable, Codable {
    let id: String
    let userId: String
    let user: User?
    let restaurantId: String
    let restaurant: Restaurant?
    let comment: String
    let photos: [PostPhoto]
    let createdAt: String

    enum CodingKeys: String, CodingKey {
        case id, userId, user, restaurantId, restaurant, comment, photos, createdAt
    }
}

struct PostPhoto: Identifiable, Codable {
    let id: String
    let postId: String
    let url: String
    let orderIndex: Int
}

struct CreatePostRequest: Codable {
    let userId: String
    let restaurantId: String
    let comment: String
    let photoUrls: [String]?
}

struct PostFeedResponse: Codable {
    let posts: [Post]
}
