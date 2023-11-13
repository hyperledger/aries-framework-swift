
import Foundation

public class AgentMessage: Codable {
    var id: String
    var type: String
    var thread: ThreadDecorator?
    var transport: TransportDecorator?

    var threadId: String {
        return thread?.threadId ?? id
    }

    private enum CodingKeys: String, CodingKey {
        case id = "@id", type = "@type", thread = "~thread", transport = "~transport"
    }

    public init(id: String? = nil, type: String) {
        self.id = id ?? UUID().uuidString
        self.type = type
    }

    public func createOutboundMessage(connection: ConnectionRecord) -> OutboundMessage {
        return OutboundMessage(payload: self, connection: connection)
    }

    func requestResponse() -> Bool {
        return true
    }

    public static func generateId() -> String {
        return UUID().uuidString
    }

    public func toJsonString() -> String {
        let encoder = JSONEncoder()
        // swiftlint:disable:next force_try
        let data = try! encoder.encode(self)
        return String(data: data, encoding: .utf8)!
    }

    public func replaceNewDidCommPrefixWithLegacyDidSov() {
        self.type = Dispatcher.replaceNewDidCommPrefixWithLegacyDidSov(messageType: self.type)
    }
}
