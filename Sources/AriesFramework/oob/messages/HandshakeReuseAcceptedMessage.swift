
import Foundation

public class HandshakeReuseAcceptedMessage: AgentMessage {
    public static var type: String = "https://didcomm.org/out-of-band/1.1/handshake-reuse-accepted"

    public init(threadId: String, parentThreadId: String) {
        super.init(type: HandshakeReuseAcceptedMessage.type)
        self.thread = ThreadDecorator(threadId: threadId, parentThreadId: parentThreadId)
    }

    public required init(from decoder: Decoder) throws {
        try super.init(from: decoder)
    }

    public override func encode(to encoder: Encoder) throws {
        try super.encode(to: encoder)
    }
}
