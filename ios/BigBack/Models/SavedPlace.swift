import Foundation

struct SavedPlace: Identifiable, Codable, Equatable {
    let id: String
    let restaurantId: String
    let foursquareId: String?
    let restaurantName: String
    let savedAt: String
}
