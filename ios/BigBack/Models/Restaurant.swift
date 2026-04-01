import Foundation

struct Restaurant: Identifiable, Codable {
    let id: String
    let foursquareId: String
    let name: String
    let lat: Double
    let lng: Double
    let cuisine: String?
    let address: String?
}

struct RestaurantSearchResult: Codable {
    let restaurants: [Restaurant]
}
