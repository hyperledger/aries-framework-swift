
import Foundation

public struct ProofIdentifier {
    public let schemaId: String
    public let credentialDefinitionId: String
    public let revocationRegistryId: String?
    public let timestamp: Int?
}

extension ProofIdentifier: Codable {
    enum CodingKeys: String, CodingKey {
        case schemaId = "schema_id"
        case credentialDefinitionId = "cred_def_id"
        case revocationRegistryId = "rev_reg_id"
        case timestamp
    }
}

public struct PartialProof {
    public let identifiers: [ProofIdentifier]
}

extension PartialProof: Codable {
    enum CodingKeys: String, CodingKey {
        case identifiers
    }
}
