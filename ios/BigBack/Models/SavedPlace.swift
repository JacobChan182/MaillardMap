import Foundation

struct SavedPlace: Identifiable, Codable {
    let id: String
    let userId: String
    let restaurantId: String
    let restaurant: Restaurant?
    let createdAt: String?
}

struct SavedPlacesResponse: Codable {
    let savedPlaces: [SavedPlace]
}
