
import Foundation

public class TrustPingMessage: AgentMessage {
    public static var type: String = "https://didcomm.org/trust_ping/1.0/ping"
    var comment: String?
    var responseRequested: Bool = false

    private enum CodingKeys: String, CodingKey {
        case comment = "comment", responseRequested = "response_requested"
    }

    public init(comment: String?, responseRequested: Bool = false) {
        self.comment = comment
        self.responseRequested = responseRequested
        super.init(id: UUID().uuidString, type: TrustPingMessage.type)
    }

    public required init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        comment = try values.decodeIfPresent(String.self, forKey: .comment)
        responseRequested = try values.decode(Bool.self, forKey: .responseRequested)
        try super.init(from: decoder)
    }

    public override func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encodeIfPresent(comment, forKey: .comment)
        try container.encode(responseRequested, forKey: .responseRequested)
        try super.encode(to: encoder)
    }

    override func requestResponse() -> Bool {
        return responseRequested
    }
}
