import Foundation

struct User: Identifiable, Codable {
    let id: String
    let username: String
    let phoneOrEmail: String?
    /// Shown in the app; login handle remains `username`.
    let displayName: String?
    let avatarUrl: String?
    /// Short profile bio; shown on profile. Max 200 characters on server.
    let bio: String?
    let createdAt: String?
    /// When true, only accepted friends (and you) can see posts on your profile.
    let profilePrivate: Bool?

    enum CodingKeys: String, CodingKey {
        case id, username, createdAt, bio
        case phoneOrEmail = "phoneOrEmail"
        case displayName = "displayName"
        case avatarUrl = "avatarUrl"
        case profilePrivate = "profilePrivate"
    }
}
