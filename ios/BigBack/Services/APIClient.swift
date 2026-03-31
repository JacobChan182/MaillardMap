import Foundation

struct APIClient {
    var baseURL: URL
    var urlSession: URLSession

    static func live(baseURL: URL = URL(string: "http://localhost:3000")!) -> APIClient {
        APIClient(baseURL: baseURL, urlSession: .shared)
    }

    func getHealth() async throws -> HealthDTO {
        let url = baseURL.appending(path: "health")
        let (data, response) = try await urlSession.data(from: url)
        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            throw URLError(.badServerResponse)
        }
        return try JSONDecoder().decode(HealthDTO.self, from: data)
    }
}

