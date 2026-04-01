import Foundation

struct BlendResult: Codable {
    let topCuisines: [CuisineCount]
    let centroid: LatLong
    let restaurants: [ScoredRestaurant]
}

struct CuisineCount: Codable, Identifiable {
    var id: String { name }
    let name: String
    let count: Int
}

struct LatLong: Codable {
    let lat: Double
    let lng: Double
}

struct ScoredRestaurant: Codable, Identifiable {
    let id: String
    let foursquareId: String
    let name: String
    let cuisine: String?
    let distance: Double
    let score: Double
}
