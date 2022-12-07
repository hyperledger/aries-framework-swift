
import Foundation

public class MediationGrantMessage: AgentMessage {
    public static var type: String = "https://didcomm.org/coordinate-mediation/1.0/mediate-grant"
    var routingKeys: [String]
    var endpoint: String

    private enum CodingKeys: String, CodingKey {
        case routingKeys = "routing_keys"
        case endpoint = "endpoint"
    }

    public init(routingKeys: [String], endpoint: String) {
        self.routingKeys = routingKeys
        self.endpoint = endpoint
        super.init(id: UUID().uuidString, type: MediationGrantMessage.type)
    }

    public required init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        routingKeys = try values.decode([String].self, forKey: .routingKeys)
        endpoint = try values.decode(String.self, forKey: .endpoint)
        try super.init(from: decoder)
    }

    public override func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(routingKeys, forKey: .routingKeys)
        try container.encode(endpoint, forKey: .endpoint)
        try super.encode(to: encoder)
    }
}
