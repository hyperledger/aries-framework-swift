
import Foundation
import Anoncreds

public struct CredentialRecord: BaseRecord {
    public var id: String
    public var createdAt: Date
    public var updatedAt: Date?
    public var tags: Tags?

    public var credentialId: String
    public var credentialRevocationId: String?
    public var revocationRegistryId: String?
    public var linkSecretId: String
    public var credential: String
    public var schemaId: String
    public var schemaName: String
    public var schemaVersion: String
    public var schemaIssuerId: String
    public var issuerId: String
    public var credentialDefinitionId: String

    public static let type = "CredentialRecord"
}

extension CredentialRecord: Codable {
    enum CodingKeys: String, CodingKey {
        case id, createdAt, updatedAt, tags, credentialId, credentialRevocationId, revocationRegistryId, linkSecretId, credential, schemaId, schemaName, schemaVersion, schemaIssuerId, issuerId, credentialDefinitionId
    }

    init(
        tags: Tags? = nil,
        credentialId: String,
        credentialRevocationId: String? = nil,
        revocationRegistryId: String? = nil,
        linkSecretId: String,
        credential: Credential,
        schemaId: String,
        schemaName: String,
        schemaVersion: String,
        schemaIssuerId: String,
        issuerId: String,
        credentialDefinitionId: String) {

        self.id = UUID().uuidString
        self.createdAt = Date()
        self.credentialId = credentialId
        self.credentialRevocationId = credentialRevocationId
        self.revocationRegistryId = revocationRegistryId
        self.linkSecretId = linkSecretId
        self.credential = credential.toJson()
        self.schemaId = schemaId
        self.schemaName = schemaName
        self.schemaVersion = schemaVersion
        self.schemaIssuerId = schemaIssuerId
        self.issuerId = issuerId
        self.credentialDefinitionId = credentialDefinitionId

        self.tags = tags ?? [:]
        for (key, value) in credential.values() {
            self.tags!["attr::\(key)::value"] = value
            self.tags!["attr::\(key)::marker"] = "1"
        }
    }

    public func getTags() -> Tags {
        var tags = self.tags ?? [:]
        tags["credentialId"] = self.credentialId
        tags["credentialRevocationId"] = self.credentialRevocationId
        tags["revocationRegistryId"] = self.revocationRegistryId
        tags["linkSecretId"] = self.linkSecretId
        tags["schemaId"] = self.schemaId
        tags["schemaName"] = self.schemaName
        tags["schemaVersion"] = self.schemaVersion
        tags["schemaIssuerId"] = self.schemaIssuerId
        tags["issuerId"] = self.issuerId
        tags["credentialDefinitionId"] = self.credentialDefinitionId
        return tags
    }
}
