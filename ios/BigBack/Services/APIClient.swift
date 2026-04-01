import Foundation

// MARK: - Errors

enum APIError: Error, LocalizedError {
    case unauthorized
    case badResponse(Int, Data?)
    case networkError(Error)
    case decodingError(Error)
    case invalidURL

    var errorDescription: String? {
        switch self {
        case .unauthorized: return "Session expired. Please log in again."
        case .badResponse(_, let data):
            if let data, let body = try? JSONDecoder().decode(ServerError.self, from: data) {
                return body.error.message
            }
            return "Something went wrong. Please try again."
        case .networkError: return "Unable to connect. Check your internet and try again."
        case .decodingError: return "Unexpected response from the server."
        case .invalidURL: return "Invalid URL"
        }
    }
}

private struct ServerError: Decodable {
    let error: ServerErrorDetail
}

private struct ServerErrorDetail: Decodable {
    let code: String?
    let message: String
}

// MARK: - API Client

final class APIClient {
    let baseURL: URL
    let session: URLSession

    private var authToken: String? {
        get { UserDefaults.standard.string(forKey: "authToken") }
        set { UserDefaults.standard.setValue(newValue, forKey: "authToken") }
    }

    init(baseURL: URL, session: URLSession = .shared) {
        self.baseURL = baseURL
        self.session = session
    }

    static func live() -> APIClient {
        APIClient(baseURL: URL(string: "http://localhost:3000")!)
    }

    private func request(_ path: String, method: String = "GET", body: Encodable? = nil) async throws -> Data {
        guard var url = URL(string: path, relativeTo: baseURL) else { throw APIError.invalidURL }
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if let token = authToken {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        if let body = body {
            request.httpBody = try JSONEncoder.default.encode(body)
        }
        do {
            let (data, response) = try await session.data(for: request)
            guard let http = response as? HTTPURLResponse else { throw APIError.badResponse(0, data) }
            if http.statusCode == 401 { throw APIError.unauthorized }
            guard (200...299).contains(http.statusCode) else { throw APIError.badResponse(http.statusCode, data) }
            return data
        } catch let err as APIError { throw err }
        catch { throw APIError.networkError(error) }
    }

    private func decode<T: Decodable>(_ type: T.Type, from data: Data) throws -> T {
        do { return try JSONDecoder.default.decode(type, from: data) }
        catch { throw APIError.decodingError(error) }
    }

    // MARK: - Auth

    func signup(username: String, password: String, phoneOrEmail: String?) async throws -> (user: User, token: String) {
        let req = SignupRequest(username: username, password: password, phoneOrEmail: phoneOrEmail)
        let data = try await request("auth/signup", method: "POST", body: req)
        let resp = try decode(AuthResponse.self, from: data)
        authToken = resp.token
        return (resp.user, resp.token)
    }

    func login(username: String, password: String) async throws -> (user: User, token: String) {
        let req = AuthRequest(username: username, password: password)
        let data = try await request("auth/login", method: "POST", body: req)
        let resp = try decode(AuthResponse.self, from: data)
        authToken = resp.token
        return (resp.user, resp.token)
    }

    // MARK: - Users

    func getUser(id: String) async throws -> User {
        let data = try await request("users/\(id)")
        return try decode(User.self, from: data)
    }

    func searchUsers(query: String) async throws -> [User] {
        let q = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? query
        let data = try await request("users/search?q=\(q)")
        return try decode([User].self, from: data)
    }

    // MARK: - Friends

    func sendFriendRequest(friendId: String) async throws {
        struct Body: Encodable { let friend_id: String }
        _ = try await request("friends/request", method: "POST", body: Body(friend_id: friendId))
    }

    func acceptFriendRequest(friendId: String) async throws {
        struct Body: Encodable { let friend_id: String }
        _ = try await request("friends/accept", method: "POST", body: Body(friend_id: friendId))
    }

    func getFriendsList() async throws -> [Friendship] {
        struct Resp: Decodable { let friends: [Friendship] }
        let data = try await request("friends/list")
        return try decode(Resp.self, from: data).friends
    }

    // MARK: - Posts

    func createPost(_ req: CreatePostRequest) async throws -> String {
        let data = try await request("posts", method: "POST", body: req)
        struct Resp: Decodable { var post: PostRef }
        struct PostRef: Decodable { let id: String }
        let resp = try decode(Resp.self, from: data)
        return resp.post.id
    }

    func getFeed() async throws -> [Post] {
        struct Resp: Decodable { var posts: [Post] }
        let data = try await request("posts/feed")
        return try decode(Resp.self, from: data).posts
    }

    func getUserPosts(userId: String) async throws -> [Post] {
        struct Resp: Decodable { var posts: [Post] }
        let data = try await request("posts/user/\(userId)")
        return try decode(Resp.self, from: data).posts
    }

    func likePost(postId: String) async throws -> Bool {
        struct Resp: Decodable { let ok: Bool; let liked: Bool }
        let data = try await request("posts/\(postId)/like", method: "POST")
        return try decode(Resp.self, from: data).liked
    }

    // MARK: - Saved Places

    func savePlace(restaurantId: String) async throws -> SavedPlace {
        struct Body: Encodable { let restaurant_id: String }
        struct Resp: Decodable { let saved_place: SavedPlace }
        let data = try await request("saved", method: "POST", body: Body(restaurant_id: restaurantId))
        return try decode(Resp.self, from: data).saved_place
    }

    func getSavedPlaces() async throws -> [SavedPlace] {
        struct Resp: Decodable { var saved_places: [SavedPlace] }
        let data = try await request("saved")
        return try decode(Resp.self, from: data).saved_places
    }

    func deleteSavedPlace(restaurantId: String) async throws {
        _ = try await request("saved/\(restaurantId)", method: "DELETE")
    }

    // MARK: - Restaurants

    func searchRestaurants(query: String, lat: Double? = nil, lng: Double? = nil) async throws -> [Restaurant] {
        var qs = "q=\(query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? query)"
        if let lat, let lng {
            qs += "&lat=\(lat)&lng=\(lng)"
        }
        let data = try await request("restaurants/search?\(qs)")
        return try decode([Restaurant].self, from: data)
    }

    func getRestaurant(id: String) async throws -> Restaurant {
        let data = try await request("restaurants/\(id)")
        return try decode(Restaurant.self, from: data)
    }

    // MARK: - Taste Blend

    func blendTastes(userIds: [String]) async throws -> BlendResult {
        let data = try await request("recommendations/blend", method: "POST", body: BlendRequest(user_ids: userIds))
        return try decode(BlendResult.self, from: data)
    }

    // MARK: - Health

    func getHealth() async throws -> HealthDTO {
        let data = try await request("health")
        return try decode(HealthDTO.self, from: data)
    }

    // MARK: - Session

    var isAuthenticated: Bool { authToken != nil }
    func clearSession() { authToken = nil }
}

// MARK: - Request/Response types

struct AuthRequest: Encodable {
    let username: String
    let password: String
}

struct SignupRequest: Encodable {
    let username: String
    let password: String
    let phoneOrEmail: String?
}

struct AuthResponse: Decodable {
    let ok: Bool
    let token: String
    let user: User
}

struct BlendRequest: Encodable {
    let user_ids: [String]
}

struct PostFeedResponse: Decodable {
    let posts: [Post]
}

struct SavedPlacesResponse: Decodable {
    let saved_places: [SavedPlace]
}

// MARK: - JSON Encoder/Decoder defaults

extension JSONEncoder {
    static let `default`: JSONEncoder = {
        let e = JSONEncoder()
        e.keyEncodingStrategy = .convertToSnakeCase
        return e
    }()
}

extension JSONDecoder {
    static let `default`: JSONDecoder = {
        let d = JSONDecoder()
        d.keyDecodingStrategy = .convertFromSnakeCase
        return d
    }()
}
