
import Foundation

public struct BatchMessageMessage: Codable {
    var id: String
    var message: EncryptedMessage
}

public class BatchMessage: AgentMessage {
    public static var type: String = "https://didcomm.org/messagepickup/1.0/batch"
    var messages: [BatchMessageMessage]

    private enum CodingKeys: String, CodingKey {
        case messages = "messages~attach"
    }

    public init(messages: [BatchMessageMessage]) {
        self.messages = messages
        super.init(id: UUID().uuidString, type: BatchMessage.type)
    }

    public required init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        messages = try values.decode([BatchMessageMessage].self, forKey: .messages)
        try super.init(from: decoder)
    }

    public override func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(messages, forKey: .messages)
        try super.encode(to: encoder)
    }
}
