
import Foundation

public struct AttributeFilter {
    public let schemaId: String?
    public let schemaName: String?
    public let schemaVersion: String?
    public let schemaIssuerDid: String?
    public let issuerDid: String?
    public let credentialDefinitionId: String?

    public init(schemaId: String? = nil, schemaName: String? = nil, schemaVersion: String? = nil, schemaIssuerDid: String? = nil, issuerDid: String? = nil, credentialDefinitionId: String? = nil) {
        self.schemaId = schemaId
        self.schemaName = schemaName
        self.schemaVersion = schemaVersion
        self.schemaIssuerDid = schemaIssuerDid
        self.issuerDid = issuerDid
        self.credentialDefinitionId = credentialDefinitionId
    }
}

extension AttributeFilter: Codable {
    private enum CodingKeys: String, CodingKey {
        case schemaId = "schema_id", schemaName = "schema_name", schemaVersion = "schema_version", schemaIssuerDid = "schema_issuer_did", issuerDid = "issuer_did", credentialDefinitionId = "cred_def_id"
    }
}
