
import Foundation

public struct IndyAgentService: Codable {
    static var type: String = "IndyAgent"
    var type: String = IndyAgentService.type
    var id: String
    var serviceEndpoint: String
    var recipientKeys: [String]
    var routingKeys: [String]?
    var priority: Int? = 0
}
