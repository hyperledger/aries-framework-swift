
import Foundation

public class ConnectionRequestMessage: AgentMessage {
    var label: String
    var imageUrl: String?
    var connection: Connection
    public static var type: String = "https://didcomm.org/connections/1.0/request"

    private enum CodingKeys: String, CodingKey {
        case label, imageUrl, connection
    }

    public init(id: String, label: String, imageUrl: String?, connection: Connection) {
        self.label = label
        self.imageUrl = imageUrl
        self.connection = connection
        super.init(id: id, type: ConnectionRequestMessage.type)
    }

    public required init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        label = try values.decode(String.self, forKey: .label)
        imageUrl = try values.decodeIfPresent(String.self, forKey: .imageUrl)
        connection = try values.decode(Connection.self, forKey: .connection)
        try super.init(from: decoder)
    }

    public override func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(label, forKey: .label)
        try container.encodeIfPresent(imageUrl, forKey: .imageUrl)
        try container.encode(connection, forKey: .connection)
        try super.encode(to: encoder)
    }
}
