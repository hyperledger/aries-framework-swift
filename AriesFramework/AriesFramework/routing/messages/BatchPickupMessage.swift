
import Foundation

class BatchPickupMessage: AgentMessage {
    public static var type: String = "https://didcomm.org/messagepickup/1.0/batch-pickup"
    var batchSize: Int

    private enum CodingKeys: String, CodingKey {
        case batchSize = "batch_size"
    }

    public init(batchSize: Int) {
        self.batchSize = batchSize
        super.init(id: UUID().uuidString, type: BatchPickupMessage.type)
    }

    public required init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        batchSize = try values.decode(Int.self, forKey: .batchSize)
        try super.init(from: decoder)
    }

    public override func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(batchSize, forKey: .batchSize)
        try super.encode(to: encoder)
    }
}
