
import Foundation

public enum DidCommMessageRole: String, Codable {
    case Sender = "sender"
    case Receiver = "receiver"
}

public struct DidCommMessageRecord: BaseRecord {
    public var id: String
    var createdAt: Date
    var updatedAt: Date?
    public var tags: Tags?

    /// Agent message encoded as json string.
    public var message: String
    public var role: DidCommMessageRole
    public var associatedRecordId: String?

    public static let type = "DidCommMessageRecord"
}

extension DidCommMessageRecord: Codable {
    enum CodingKeys: String, CodingKey {
        case id, createdAt, updatedAt, tags, message, role, associatedRecordId
    }

    init(
        tags: Tags? = nil,
        message: AgentMessage,
        role: DidCommMessageRole,
        associatedRecordId: String? = nil) {

        self.id = DidCommMessageRecord.generateId()
        self.createdAt = Date()
        self.tags = tags
        self.message = message.toJsonString()
        self.role = role
        self.associatedRecordId = associatedRecordId
    }

    public func getTags() -> Tags {
        var tags = self.tags ?? [:]

        if let agentMessage = try? JSONDecoder().decode(AgentMessage.self, from: message.data(using: .utf8)!) {
            tags["messageId"] = agentMessage.id
            tags["messageType"] = agentMessage.type
        }
        tags["role"] = self.role.rawValue
        tags["associatedRecordId"] = self.associatedRecordId

        return tags
    }
}
