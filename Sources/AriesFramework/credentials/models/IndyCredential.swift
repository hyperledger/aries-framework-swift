
import Foundation

public struct IndyCredential {
    public let schemaId: String
    public let credentialDefinitionId: String
    public let revocationRegistryId: String?
    public let credentialRevocationId: String?
}

extension IndyCredential: Decodable {
    enum CodingKeys: String, CodingKey {
        case schemaId = "schema_id"
        case credentialDefinitionId = "cred_def_id"
        case revocationRegistryId = "rev_reg_id"
        case credentialRevocationId = "cred_rev_id"
    }
}
