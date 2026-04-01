import Foundation

struct User: Identifiable, Codable {
    let id: String
    let username: String
    let phoneOrEmail: String?
    let createdAt: String?

    enum CodingKeys: String, CodingKey {
        case id, username, createdAt
        case phoneOrEmail = "phoneOrEmail"
    }
}
