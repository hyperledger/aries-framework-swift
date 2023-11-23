
import Foundation

public struct RevocationRegistryRecord: BaseRecord {
    public var id: String
    var createdAt: Date
    var updatedAt: Date?
    public var tags: Tags?

    public var credDefId: String
    public var revocRegId: String
    public var revocRegDef: String
    public var revocRegPrivate: String
    public var revocStatusList: String
    public var registryIndex: Int = 0

    public static let type = "RevocationRegistryRecord"
}

extension RevocationRegistryRecord: Codable {
    enum CodingKeys: String, CodingKey {
        case id, createdAt, updatedAt, tags, credDefId, revocRegId, revocRegDef, revocRegPrivate, revocStatusList, registryIndex
    }

    init(
        tags: Tags? = nil,
        credDefId: String,
        revocRegId: String,
        revocRegDef: String,
        revocRegPrivate: String,
        revocStatusList: String) {

        self.id = RevocationRegistryRecord.generateId()
        self.createdAt = Date()
        self.tags = tags
        self.credDefId = credDefId
        self.revocRegId = revocRegId
        self.revocRegDef = revocRegDef
        self.revocRegPrivate = revocRegPrivate
        self.revocStatusList = revocStatusList
    }

    public func getTags() -> Tags {
        var tags = self.tags ?? [:]

        tags["credDefId"] = self.credDefId
        tags["revocRegId"] = self.revocRegId

        return tags
    }
}
