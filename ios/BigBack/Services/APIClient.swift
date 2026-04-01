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
        case .unauthorized:
            return "Unauthorized. Please log in again."
        case .badResponse(let code, _):
            return "Server returned \(code)"
        case .networkError(let e):
            return e.localizedDescription
        case .decodingError(let e):
            return "Data error: \(e.localizedDescription)"
        case .invalidURL:
            return "Invalid URL"
        }
    }
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

    // MARK: - Helpers

    private func request(
        _ path: String,
        method: String = "GET",
        body: Encodable? = nil
    ) async throws -> Data {
        guard var url = URL(string: path, relativeTo: baseURL) else {
            throw APIError.invalidURL
        }
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
            guard let http = response as? HTTPURLResponse else {
                throw APIError.badResponse(0, data)
            }
            if http.statusCode == 401 {
                throw APIError.unauthorized
            }
            guard (200...299).contains(http.statusCode) else {
                throw APIError.badResponse(http.statusCode, data)
            }
            return data
        } catch let err as APIError {
            throw err
        } catch {
            throw APIError.networkError(error)
        }
    }

    private func decode<T: Decodable>(_ type: T.Type, from data: Data) throws -> T {
        do {
            return try JSONDecoder.default.decode(type, from: data)
        } catch {
            throw APIError.decodingError(error)
        }
    }

    // MARK: - Auth

    struct AuthRequest: Codable {
        let phoneOrEmail: String
        let password: String
    }

    struct AuthResponse: Codable {
        let ok: Bool
        let token: String
        let user: User
    }

    func signup(phoneOrEmail: String, password: String, username: String) async throws -> AuthResponse {
        var body: [String: String] = ["phoneOrEmail": phoneOrEmail, "password": password, "username": username]
        return try await sendAuth(method: "POST", path: "auth/signup", body: body)
    }

    func login(phoneOrEmail: String, password: String) async throws -> AuthResponse {
        let body: [String: String] = ["phoneOrEmail": phoneOrEmail, "password": password]
        return try await sendAuth(method: "POST", path: "auth/login", body: body)
    }

    private func sendAuth(method: String, path: String, body: [String: String]) async throws -> AuthResponse {
        guard let url = URL(string: path, relativeTo: baseURL) else {
            throw APIError.invalidURL
        }
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder.default.encode(body)

        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            throw APIError.badResponse((response as? HTTPURLResponse)?.statusCode ?? 0, data)
        }
        let resp = try decode(AuthResponse.self, from: data)
        authToken = resp.token
        return resp
    }

    // MARK: - Users

    func getUser(id: String) async throws -> User {
        let data = try await request("users/\(id)")
        return try decode(User.self, from: data)
    }

    func searchUsers(query: String) async throws -> [User] {
        let data = try await request("users/search?q=\(query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? query)")
        return try decode([User].self, from: data)
    }

    // MARK: - Friends

    func sendFriendRequest(friendId: String) async throws {
        let body: [String: String] = ["friendId": friendId]
        _ = try await request("friends/request", method: "POST", body: body)
    }

    func acceptFriend(requestId: String) async throws {
        let body: [String: String] = ["requestId": requestId]
        _ = try await request("friends/accept", method: "POST", body: body)
    }

    func getFriendsList() async throws -> [Friendship] {
        let data = try await request("friends/list")
        return try decode([Friendship].self, from: data)
    }

    // MARK: - Posts

    func createPost(_ req: CreatePostRequest) async throws -> Post {
        let data = try await request("posts", method: "POST", body: req)
        return try decode(Post.self, from: data)
    }

    func getFeed() async throws -> [Post] {
        let data = try await request("posts/feed")
        let resp = try decode(PostFeedResponse.self, from: data)
        return resp.posts
    }

    func getUserPosts(userId: String) async throws -> [Post] {
        let data = try await request("posts/user/\(userId)")
        return try decode([Post].self, from: data)
    }

    func likePost(postId: String) async throws {
        _ = try await request("posts/\(postId)/like", method: "POST")
    }

    // MARK: - Saved Places

    func savePlace(restaurantId: String) async throws {
        let body: [String: String] = ["restaurantId": restaurantId]
        _ = try await request("saved", method: "POST", body: body)
    }

    func getSavedPlaces() async throws -> [SavedPlace] {
        let data = try await request("saved")
        let resp = try decode(SavedPlacesResponse.self, from: data)
        return resp.savedPlaces
    }

    func deleteSavedPlace(restaurantId: String) async throws {
        _ = try await request("saved/\(restaurantId)", method: "DELETE")
    }

    // MARK: - Restaurants

    func searchRestaurants(query: String) async throws -> [Restaurant] {
        let data = try await request("restaurants/search?q=\(query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? query)")
        let resp = try decode(RestaurantSearchResult.self, from: data)
        return resp.restaurants
    }

    func getRestaurant(id: String) async throws -> Restaurant {
        let data = try await request("restaurants/\(id)")
        return try decode(Restaurant.self, from: data)
    }

    // MARK: - Taste Blend

    func blendTastes(userIds: [String]) async throws -> [BlendRecommendation] {
        let req = BlendRequest(userIds: userIds)
        let data = try await request("recommendations/blend", method: "POST", body: req)
        let resp = try decode(BlendResponse.self, from: data)
        return resp.recommendations
    }

    // MARK: - Health

    func getHealth() async throws -> HealthDTO {
        let data = try await request("health")
        return try decode(HealthDTO.self, from: data)
    }

    // MARK: - Session

    var isAuthenticated: Bool {
        authToken != nil
    }

    func clearSession() {
        authToken = nil
    }
}

// MARK: - JSON Encoder/Decoder defaults

extension JSONEncoder {
    static let `default`: JSONEncoder = {
        let e = JSONEncoder()
        e.keyEncodingStrategy = .convertToSnakeCase
        e.dateEncodingStrategy = .iso8601
        return e
    }()
}

extension JSONDecoder {
    static let `default`: JSONDecoder = {
        let d = JSONDecoder()
        d.keyDecodingStrategy = .convertFromSnakeCase
        d.dateDecodingStrategy = .iso8601
        return d
    }()
}
