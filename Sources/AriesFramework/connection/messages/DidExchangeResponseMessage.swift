
import Foundation

public class DidExchangeResponseMessage: AgentMessage {
    var did: String
    var didDoc: Attachment?
    public static var type: String = "https://didcomm.org/didexchange/1.0/response"

    private enum CodingKeys: String, CodingKey {
        case did, didDoc = "did_doc~attach"
    }

    public init(id: String? = nil, threadId: String, did: String, didDoc: Attachment?) {
        self.did = did
        self.didDoc = didDoc
        super.init(id: id, type: DidExchangeResponseMessage.type)

        self.thread = ThreadDecorator(threadId: threadId)
    }

    public required init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        did = try values.decode(String.self, forKey: .did)
        didDoc = try values.decodeIfPresent(Attachment.self, forKey: .didDoc)
        try super.init(from: decoder)
    }

    public override func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(did, forKey: .did)
        try container.encodeIfPresent(didDoc, forKey: .didDoc)
        try super.encode(to: encoder)
    }
}
