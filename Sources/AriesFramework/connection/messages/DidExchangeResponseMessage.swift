
import Foundation

public class DidExchangeResponseMessage: AgentMessage {
    var did: String
    var didDoc: Attachment?
    var didRotate: Attachment?
    public static var type: String = "https://didcomm.org/didexchange/1.1/response"

    private enum CodingKeys: String, CodingKey {
        case did, didDoc = "did_doc~attach", didRotate = "did_rotate~attach"
    }

    public init(id: String? = nil, threadId: String, did: String, didDoc: Attachment? = nil, didRotate: Attachment? = nil) {
        self.did = did
        self.didDoc = didDoc
        self.didRotate = didRotate
        super.init(id: id, type: DidExchangeResponseMessage.type)

        self.thread = ThreadDecorator(threadId: threadId)
    }

    public required init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        did = try values.decode(String.self, forKey: .did)
        didDoc = try values.decodeIfPresent(Attachment.self, forKey: .didDoc)
        didRotate = try values.decodeIfPresent(Attachment.self, forKey: .didRotate)
        try super.init(from: decoder)
    }

    public override func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(did, forKey: .did)
        try container.encodeIfPresent(didDoc, forKey: .didDoc)
        try container.encodeIfPresent(didRotate, forKey: .didRotate)
        try super.encode(to: encoder)
    }
}
