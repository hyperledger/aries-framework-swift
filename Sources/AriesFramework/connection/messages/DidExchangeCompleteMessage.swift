
import Foundation

public class DidExchangeCompleteMessage: AgentMessage {
    public static var type: String = "https://didcomm.org/didexchange/1.0/complete"

    public init(id: String? = nil, threadId: String, parentThreadId: String) {
        super.init(id: id, type: DidExchangeCompleteMessage.type)

        self.thread = ThreadDecorator(threadId: threadId, parentThreadId: parentThreadId)
    }

    public required init(from decoder: Decoder) throws {
        try super.init(from: decoder)
    }

    public override func encode(to encoder: Encoder) throws {
        try super.encode(to: encoder)
    }
}
