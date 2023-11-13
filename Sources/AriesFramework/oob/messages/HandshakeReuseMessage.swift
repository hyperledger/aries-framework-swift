
import Foundation

public class HandshakeReuseMessage: AgentMessage {
    public static var type: String = "https://didcomm.org/out-of-band/1.1/handshake-reuse"

    public init(parentThreadId: String) {
        super.init(type: HandshakeReuseMessage.type)
        self.thread = ThreadDecorator(threadId: id, parentThreadId: parentThreadId)
    }

    public required init(from decoder: Decoder) throws {
        try super.init(from: decoder)
    }

    public override func encode(to encoder: Encoder) throws {
        try super.encode(to: encoder)
    }
}
