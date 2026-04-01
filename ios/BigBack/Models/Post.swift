import Foundation

struct Post: Identifiable, Codable, Equatable {
    let id: String
    let userId: String
    let username: String
    let restaurantId: String
    let restaurantName: String
    let lat: Double
    let lng: Double
    let comment: String?
    let photos: [PostPhoto]
    let liked: Bool
    let likeCount: Int
    let createdAt: String
}

struct PostPhoto: Identifiable, Codable, Equatable {
    let id: String
    let postId: String
    let url: String
    let orderIndex: Int
}

struct CreatePostRequest: Codable {
    let foursquare_id: String
    let comment: String?
    let photo_urls: [String]?
}
