
import Foundation

public struct CredentialRecordBinding: Codable {
    public let credentialRecordType: String
    public let credentialRecordId: String
}

public struct CredentialExchangeRecord: BaseRecord {
    public var id: String
    public var createdAt: Date
    public var updatedAt: Date?
    public var tags: Tags?

    public var connectionId: String
    public var threadId: String
    public var state: CredentialState
    public var autoAcceptCredential: AutoAcceptCredential?
    public var errorMessage: String?
    public var protocolVersion: String
    public var credentials: [CredentialRecordBinding]
    public var credentialAttributes: [CredentialPreviewAttribute]?
    public var indyRequestMetadata: String?
    public var credentialDefinitionId: String?

    public static let type = "CredentialRecord"
}

extension CredentialExchangeRecord: Codable {
    enum CodingKeys: String, CodingKey {
        case id, createdAt, updatedAt, tags, connectionId, threadId, state, autoAcceptCredential, errorMessage, protocolVersion, credentials, credentialAttributes, indyRequestMetadata, credentialDefinitionId
    }

    init(
        tags: Tags? = nil,
        connectionId: String,
        threadId: String,
        state: CredentialState,
        autoAcceptCredential: AutoAcceptCredential? = nil,
        errorMessage: String? = nil,
        protocolVersion: String,
        credentials: [CredentialRecordBinding]? = nil,
        credentialAttributes: [CredentialPreviewAttribute]? = nil) {

        self.id = UUID().uuidString
        self.createdAt = Date()
        self.tags = tags
        self.connectionId = connectionId
        self.threadId = threadId
        self.state = state
        self.autoAcceptCredential = autoAcceptCredential
        self.errorMessage = errorMessage
        self.protocolVersion = protocolVersion
        self.credentials = credentials ?? []
        self.credentialAttributes = credentialAttributes
    }

    public func getTags() -> Tags {
        var tags = self.tags ?? [:]

        let credentialIds = self.credentials.map { $0.credentialRecordId }

        tags["threadId"] = self.threadId
        tags["connectionId"] = connectionId
        tags["state"] = self.state.rawValue
        tags["credentialIds"] = credentialIds.joined(separator: ",")

        return tags
    }

    public func getCredentialInfo() -> IndyCredentialView? {
        guard let credentialAttributes = self.credentialAttributes else {
            return nil
        }

        let claims = credentialAttributes.reduce(into: [String: String]()) { (accumulator, current) in
            accumulator[current.name] = current.value
        }

        return IndyCredentialView(claims: claims)
    }

    public func assertProtocolVersion(_ version: String) throws {
        if self.protocolVersion != version {
            throw AriesFrameworkError.frameworkError(
                "Credential record has invalid protocol version \(self.protocolVersion). Expected version \(version)"
            )
        }
    }

    public func assertState(_ expectedStates: CredentialState...) throws {
        if !expectedStates.contains(self.state) {
            throw AriesFrameworkError.frameworkError(
                "Credential record is in invalid state \(self.state). Valid states are: \(expectedStates)"
            )
        }
    }

    public func assertConnection(_ currentConnectionId: String) throws {
        if self.connectionId != currentConnectionId {
            throw AriesFrameworkError.frameworkError(
                "Credential record is associated with connection '\(self.connectionId)'. Current connection is '\(currentConnectionId)'"
            )
        }
    }
}
