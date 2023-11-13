
import Foundation

public class ProposeCredentialMessage: AgentMessage {
    public static var type: String = "https://didcomm.org/issue-credential/1.0/propose-credential"

    public var comment: String?
    public var credentialPreview: CredentialPreview?
    public var schemaIssuerDid: String?
    public var schemaId: String?
    public var schemaName: String?
    public var schemaVersion: String?
    public var credentialDefinitionId: String?
    public var issuerDid: String?

    private enum CodingKeys: String, CodingKey {
        case comment, credentialPreview = "credential_proposal", schemaIssuerDid = "schema_issuer_did", schemaId = "schema_id", schemaName = "schema_name", schemaVersion = "schema_version", credentialDefinitionId = "cred_def_id", issuerDid = "issuer_did"
    }

    public init(id: String? = nil, comment: String? = nil, credentialPreview: CredentialPreview? = nil, schemaIssuerDid: String? = nil, schemaId: String? = nil, schemaName: String? = nil, schemaVersion: String? = nil, credentialDefinitionId: String? = nil, issuerDid: String? = nil) {
        self.comment = comment
        self.credentialPreview = credentialPreview
        self.schemaIssuerDid = schemaIssuerDid
        self.schemaId = schemaId
        self.schemaName = schemaName
        self.schemaVersion = schemaVersion
        self.credentialDefinitionId = credentialDefinitionId
        self.issuerDid = issuerDid
        super.init(id: id, type: ProposeCredentialMessage.type)
    }

    public required init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        comment = try values.decodeIfPresent(String.self, forKey: .comment)
        credentialPreview = try values.decodeIfPresent(CredentialPreview.self, forKey: .credentialPreview)
        schemaIssuerDid = try values.decodeIfPresent(String.self, forKey: .schemaIssuerDid)
        schemaId = try values.decodeIfPresent(String.self, forKey: .schemaId)
        schemaName = try values.decodeIfPresent(String.self, forKey: .schemaName)
        schemaVersion = try values.decodeIfPresent(String.self, forKey: .schemaVersion)
        credentialDefinitionId = try values.decodeIfPresent(String.self, forKey: .credentialDefinitionId)
        issuerDid = try values.decodeIfPresent(String.self, forKey: .issuerDid)
        try super.init(from: decoder)
    }

    public override func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encodeIfPresent(comment, forKey: .comment)
        try container.encodeIfPresent(credentialPreview, forKey: .credentialPreview)
        try container.encodeIfPresent(schemaIssuerDid, forKey: .schemaIssuerDid)
        try container.encodeIfPresent(schemaId, forKey: .schemaId)
        try container.encodeIfPresent(schemaName, forKey: .schemaName)
        try container.encodeIfPresent(schemaVersion, forKey: .schemaVersion)
        try container.encodeIfPresent(credentialDefinitionId, forKey: .credentialDefinitionId)
        try container.encodeIfPresent(issuerDid, forKey: .issuerDid)
        try super.encode(to: encoder)
    }
}
