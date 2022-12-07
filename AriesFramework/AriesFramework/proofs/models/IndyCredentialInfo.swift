
import Foundation

// Return type of IndyAnoncreds.proverGetCredentials()
public struct CredentialsForProof: Decodable {
    public let attrs: [String: [CredInfoForProof]]
    public let predicates: [String: [CredInfoForProof]]
}

public struct CredInfoForProof: Decodable {
    public let credentialInfo: IndyCredentialInfo

    enum CodingKeys: String, CodingKey {
        case credentialInfo = "cred_info"
    }
}

public struct IndyCredentialInfo: Decodable {
    public let referent: String
    public let attributes: [String: String]
    public let schemaId: String
    public let credentialDefinitionId: String
    public let revocationRegistryId: String?
    public let credentialRevocationId: String?

    enum CodingKeys: String, CodingKey {
        case referent = "referent"
        case attributes = "attrs"
        case schemaId = "schema_id"
        case credentialDefinitionId = "cred_def_id"
        case revocationRegistryId = "rev_reg_id"
        case credentialRevocationId = "cred_rev_id"
    }
}
