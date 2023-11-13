
import Foundation

enum KeylistUpdateResult: String, Codable {
    case ClientError = "client_error"
    case ServerError = "server_error"
    case NoChange = "no_change"
    case Success = "success"
}

struct KeylistUpdated: Codable {
    var recipientKey: String
    var action: KeylistUpdateAction
    var result: KeylistUpdateResult

    enum CodingKeys: String, CodingKey {
        case recipientKey = "recipient_key", action, result
    }
}

class KeylistUpdateResponseMessage: AgentMessage {
    public static var type: String = "https://didcomm.org/coordinate-mediation/1.0/keylist-update-response"
    var updated: [KeylistUpdated]

    private enum CodingKeys: String, CodingKey {
        case updated
    }

    public init(updated: [KeylistUpdated]) {
        self.updated = updated
        super.init(id: UUID().uuidString, type: KeylistUpdateResponseMessage.type)
    }

    public required init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        updated = try values.decode([KeylistUpdated].self, forKey: .updated)
        try super.init(from: decoder)
    }

    public override func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(updated, forKey: .updated)
        try super.encode(to: encoder)
    }
}
