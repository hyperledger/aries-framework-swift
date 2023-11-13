
import Foundation

public class ConnectionResponseMessage: AgentMessage {
    var connectionSig: SignatureDecorator
    public static var type: String = "https://didcomm.org/connections/1.0/response"

    private enum CodingKeys: String, CodingKey {
        case connectionSig = "connection~sig"
    }

    public init(id: String? = nil, connectionSig: SignatureDecorator) {
        self.connectionSig = connectionSig
        super.init(id: id, type: ConnectionResponseMessage.type)
    }

    public required init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        connectionSig = try values.decode(SignatureDecorator.self, forKey: .connectionSig)
        try super.init(from: decoder)
    }

    public override func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(connectionSig, forKey: .connectionSig)
        try super.encode(to: encoder)
    }
}
