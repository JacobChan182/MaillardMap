import Foundation

struct BlendRequest: Codable {
    let userIds: [String]
}

struct BlendRecommendation: Codable {
    let restaurant: Restaurant
    let cuisineMatchScore: Int
    let distanceToCentroid: Double
}

struct BlendResponse: Codable {
    let recommendations: [BlendRecommendation]
}
