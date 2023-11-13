
import Foundation

enum KeylistUpdateAction: String, Codable {
    case add
    case remove
}

struct KeylistUpdate: Codable {
    var recipientKey: String
    var action: KeylistUpdateAction

    enum CodingKeys: String, CodingKey {
        case recipientKey = "recipient_key", action
    }
}

class KeylistUpdateMessage: AgentMessage {
    public static var type: String = "https://didcomm.org/coordinate-mediation/1.0/keylist-update"
    var updates: [KeylistUpdate]

    private enum CodingKeys: String, CodingKey {
        case updates
    }

    public init(updates: [KeylistUpdate]) {
        self.updates = updates
        super.init(id: UUID().uuidString, type: KeylistUpdateMessage.type)
    }

    public required init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        updates = try values.decode([KeylistUpdate].self, forKey: .updates)
        try super.init(from: decoder)
    }

    public override func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(updates, forKey: .updates)
        try super.encode(to: encoder)
    }
}
