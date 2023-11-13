
import Foundation

public struct ProofExchangeRecord: BaseRecord {
    public var id: String
    public var createdAt: Date
    public var updatedAt: Date?
    public var tags: Tags?

    public var connectionId: String
    public var threadId: String
    public var isVerified: Bool?
    public var presentationId: String?
    public var state: ProofState
    public var autoAcceptProof: AutoAcceptProof?
    public var errorMessage: String?

    public static let type = "ProofRecord"
}

extension ProofExchangeRecord: Codable {
    enum CodingKeys: String, CodingKey {
        case id, createdAt, updatedAt, tags, connectionId, threadId, isVerified, presentationId, state, autoAcceptProof, errorMessage
    }

    init(
        tags: Tags? = nil,
        connectionId: String,
        threadId: String,
        isVerified: Bool? = nil,
        presentationId: String? = nil,
        state: ProofState,
        autoAcceptProof: AutoAcceptProof? = nil,
        errorMessage: String? = nil) {

        self.id = UUID().uuidString
        self.createdAt = Date()
        self.tags = tags
        self.connectionId = connectionId
        self.threadId = threadId
        self.isVerified = isVerified
        self.presentationId = presentationId
        self.state = state
        self.autoAcceptProof = autoAcceptProof
        self.errorMessage = errorMessage
    }

    public func getTags() -> Tags {
        var tags = self.tags ?? [:]

        tags["threadId"] = self.threadId
        tags["connectionId"] = self.connectionId
        tags["state"] = self.state.rawValue

        return tags
    }

    public func assertState(_ expectedStates: ProofState...) throws {
        if !expectedStates.contains(self.state) {
            throw AriesFrameworkError.frameworkError(
                "Proof record is in invalid state \(self.state). Valid states are: \(expectedStates)"
            )
        }
    }

    public func assertConnection(_ currentConnectionId: String) throws {
        if self.connectionId != currentConnectionId {
            throw AriesFrameworkError.frameworkError(
                "Proof record is associated with connection '\(self.connectionId)'. Current connection is '\(currentConnectionId)'"
            )
        }
    }
}
