
import Foundation

public enum MediationState: String, Codable {
    case Requested
    case Granted
    case Denied
}

public enum MediationRole: String, Codable {
    case Mediator = "MEDIATOR"
    case Recipient = "RECIPIENT"
}

public struct MediationRecord: BaseRecord {
    public static var type = "MediationRecord"

    public var id: String
    public var createdAt: Date
    public var updatedAt: Date?
    public var tags: Tags?

    public var state: MediationState
    public var role: MediationRole
    public var connectionId: String
    public var threadId: String
    public var endpoint: String?
    public var recipientKeys: [String]
    public var routingKeys: [String]
    public var invitationUrl: String
}

extension MediationRecord: Codable {
    enum CodingKeys: String, CodingKey {
        case id, createdAt, updatedAt, state, role, connectionId, threadId, endpoint, recipientKeys, routingKeys, invitationUrl
    }

    public init(
        tags: Tags? = nil,
        state: MediationState,
        role: MediationRole,
        connectionId: String,
        threadId: String,
        endpoint: String? = nil,
        recipientKeys: [String] = [],
        routingKeys: [String] = [],
        invitationUrl: String) {

        self.id = UUID().uuidString
        self.createdAt = Date()
        self.tags = tags
        self.state = state
        self.role = role
        self.connectionId = connectionId
        self.threadId = threadId
        self.endpoint = endpoint
        self.recipientKeys = recipientKeys
        self.routingKeys = routingKeys
        self.invitationUrl = invitationUrl
    }

    public func getTags() -> Tags {
        var tags = self.tags ?? [:]

        tags["state"] = self.state.rawValue
        tags["role"] = self.role.rawValue
        tags["connectionId"] = self.connectionId
        tags["threadId"] = self.threadId
        tags["recipientKeys"] = Tags.stringFromArray(self.recipientKeys)

        return tags
    }

    public func isReady() -> Bool {
        return [MediationState.Granted].contains(state)
    }

    public func assertReady() throws {
        if !isReady() {
            throw AriesFrameworkError.frameworkError("Mediation record is not ready to be used. Expected \(MediationState.Granted), found invalid state \(state)")
        }
    }

    public func assertState(_ expectedStates: MediationState...) throws {
        if !expectedStates.contains(state) {
            throw AriesFrameworkError.frameworkError("Mediation record is in invalid state \(state). Valid states are: \(expectedStates.map { $0.rawValue }.joined(separator: ", ")).")
        }
    }

    public func assertRole(_ expectedRole: MediationRole) throws {
        if role != expectedRole {
            throw AriesFrameworkError.frameworkError("Mediation record has invalid role \(role). Expected role \(expectedRole).")
        }
    }
}
