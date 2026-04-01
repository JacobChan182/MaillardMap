import Foundation

struct HealthDTO: Decodable {
    let ok: Bool
    let service: String
    let time: String?
}
