
import Foundation

public class ForwardMessage: AgentMessage {
    public static var type: String = "https://didcomm.org/routing/1.0/forward"
    var to: String
    var message: EncryptedMessage

    private enum CodingKeys: String, CodingKey {
        case to, message = "msg"
    }

    public init(to: String, message: EncryptedMessage) {
        self.to = to
        self.message = message
        super.init(id: UUID().uuidString, type: ForwardMessage.type)
    }

    public required init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        to = try values.decode(String.self, forKey: .to)
        message = try values.decode(EncryptedMessage.self, forKey: .message)
        try super.init(from: decoder)
    }

    public override func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(to, forKey: .to)
        try container.encode(message, forKey: .message)
        try super.encode(to: encoder)
    }
}
