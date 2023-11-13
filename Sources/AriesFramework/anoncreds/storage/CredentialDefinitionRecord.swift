
import Foundation

public struct CredentialDefinitionRecord: BaseRecord {
    public var id: String
    var createdAt: Date
    var updatedAt: Date?
    public var tags: Tags?

    public var schemaId: String
    public var credDefId: String
    public var credDef: String
    public var credDefPriv: String
    public var keyCorrectnessProof: String

    public static let type = "CredentialDefinitionRecord"
}

extension CredentialDefinitionRecord: Codable {
    enum CodingKeys: String, CodingKey {
        case id, createdAt, updatedAt, tags, schemaId, credDefId, credDef, credDefPriv, keyCorrectnessProof
    }

    init(
        tags: Tags? = nil,
        schemaId: String,
        credDefId: String,
        credDef: String,
        credDefPriv: String,
        keyCorrectnessProof: String) {

        self.id = CredentialDefinitionRecord.generateId()
        self.createdAt = Date()
        self.tags = tags
        self.schemaId = schemaId
        self.credDefId = credDefId
        self.credDef = credDef
        self.credDefPriv = credDefPriv
        self.keyCorrectnessProof = keyCorrectnessProof
    }

    public func getTags() -> Tags {
        var tags = self.tags ?? [:]

        tags["schemaId"] = self.schemaId
        tags["credDefId"] = self.credDefId

        return tags
    }
}
