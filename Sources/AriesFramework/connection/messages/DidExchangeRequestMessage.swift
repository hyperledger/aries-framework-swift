
import Foundation

public class DidExchangeRequestMessage: AgentMessage {
    var label: String
    var goalCode: String?
    var goal: String?
    var did: String
    public static var type: String = "https://didcomm.org/didexchange/1.1/request"

    private enum CodingKeys: String, CodingKey {
        case label, goalCode = "goal_code", goal, did
    }

    public init(id: String, label: String, goalCode: String?, goal: String?, did: String) {
        self.label = label
        self.goalCode = goalCode
        self.goal = goal
        self.did = did
        super.init(id: id, type: DidExchangeRequestMessage.type)
    }

    public required init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        label = try values.decode(String.self, forKey: .label)
        goalCode = try values.decodeIfPresent(String.self, forKey: .goalCode)
        goal = try values.decodeIfPresent(String.self, forKey: .goal)
        did = try values.decode(String.self, forKey: .did)
        try super.init(from: decoder)
    }

    public override func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(label, forKey: .label)
        try container.encodeIfPresent(goalCode, forKey: .goalCode)
        try container.encodeIfPresent(goal, forKey: .goal)
        try container.encode(did, forKey: .did)
        try super.encode(to: encoder)
    }
}
