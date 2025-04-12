import Foundation

struct User: Identifiable, Codable {
    let id: UUID
    let username: String
    let email: String
    var subscriptionLevel: SubscriptionLevel = .basic
    
    enum SubscriptionLevel: String, Codable {
        case basic
        case premium
    }
    
    enum CodingKeys: String, CodingKey {
        case id
        case username
        case email
        case subscriptionLevel
    }
} 