
import Foundation

public class MediationRequestMessage: AgentMessage {
    public static var type: String = "https://didcomm.org/coordinate-mediation/1.0/mediate-request"
    var sentTime: Date

    private enum CodingKeys: String, CodingKey {
        case sentTime = "sent_time"
    }

    public init(sentTime: Date) {
        self.sentTime = sentTime
        super.init(id: UUID().uuidString, type: MediationRequestMessage.type)
    }

    public required init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        sentTime = try values.decode(Date.self, forKey: .sentTime)
        try super.init(from: decoder)
    }

    public override func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(sentTime, forKey: .sentTime)
        try super.encode(to: encoder)
    }
}
