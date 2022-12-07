
import Foundation

public class PresentationAckMessage: AgentMessage {
    public static var type: String = "https://didcomm.org/present-proof/1.0/ack"
    var status: AckStatus

    private enum CodingKeys: String, CodingKey {
        case status
    }

    public init(id: String? = nil, threadId: String, status: AckStatus) {
        self.status = status
        super.init(id: id, type: PresentationAckMessage.type)

        self.thread = ThreadDecorator(threadId: threadId)
    }

    public required init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        status = try values.decode(AckStatus.self, forKey: .status)
        try super.init(from: decoder)
    }

    public override func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(status, forKey: .status)
        try super.encode(to: encoder)
    }
}
