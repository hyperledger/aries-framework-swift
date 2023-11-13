
import Foundation

public class MediationDenyMessage: AgentMessage {
    public static var type: String = "https://didcomm.org/coordinate-mediation/1.0/mediate-deny"

    public init() {
        super.init(id: UUID().uuidString, type: MediationDenyMessage.type)
    }

    public required init(from decoder: Decoder) throws {
        try super.init(from: decoder)
    }

    public override func encode(to encoder: Encoder) throws {
        try super.encode(to: encoder)
    }
}
