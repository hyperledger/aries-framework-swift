
import Foundation

public struct CreateProposalOptions {
    public var connection: ConnectionRecord
    public var credentialPreview: CredentialPreview?
    public var schemaIssuerDid: String?
    public var schemaId: String?
    public var schemaName: String?
    public var schemaVersion: String?
    public var credentialDefinitionId: String?
    public var issuerDid: String?
    public var autoAcceptCredential: AutoAcceptCredential?
    public var comment: String?

    public init(connection: ConnectionRecord, credentialPreview: CredentialPreview? = nil, schemaIssuerDid: String? = nil, schemaId: String? = nil, schemaName: String? = nil, schemaVersion: String? = nil, credentialDefinitionId: String? = nil, issuerDid: String? = nil, autoAcceptCredential: AutoAcceptCredential? = nil, comment: String? = nil) {
        self.connection = connection
        self.credentialPreview = credentialPreview
        self.schemaIssuerDid = schemaIssuerDid
        self.schemaId = schemaId
        self.schemaName = schemaName
        self.schemaVersion = schemaVersion
        self.credentialDefinitionId = credentialDefinitionId
        self.issuerDid = issuerDid
        self.autoAcceptCredential = autoAcceptCredential
        self.comment = comment
    }
}

public struct CreateOfferOptions {
    public var connection: ConnectionRecord?
    public var credentialDefinitionId: String
    public var attributes: [CredentialPreviewAttribute]
    public var autoAcceptCredential: AutoAcceptCredential?
    public var comment: String?

    public init(connection: ConnectionRecord? = nil, credentialDefinitionId: String, attributes: [CredentialPreviewAttribute], autoAcceptCredential: AutoAcceptCredential? = nil, comment: String? = nil) {
        self.connection = connection
        self.credentialDefinitionId = credentialDefinitionId
        self.attributes = attributes
        self.autoAcceptCredential = autoAcceptCredential
        self.comment = comment
    }
}

public struct AcceptOfferOptions {
    public var credentialRecordId: String
    public var holderDid: String?
    public var autoAcceptCredential: AutoAcceptCredential?
    public var comment: String?

    public init(credentialRecordId: String, holderDid: String? = nil, autoAcceptCredential: AutoAcceptCredential? = nil, comment: String? = nil) {
        self.credentialRecordId = credentialRecordId
        self.holderDid = holderDid
        self.autoAcceptCredential = autoAcceptCredential
        self.comment = comment
    }
}

public struct AcceptRequestOptions {
    public var credentialRecordId: String
    public var autoAcceptCredential: AutoAcceptCredential?
    public var comment: String?

    public init(credentialRecordId: String, autoAcceptCredential: AutoAcceptCredential? = nil, comment: String? = nil) {
        self.credentialRecordId = credentialRecordId
        self.autoAcceptCredential = autoAcceptCredential
        self.comment = comment
    }
}

public struct AcceptCredentialOptions {
    public var credentialRecordId: String

    public init(credentialRecordId: String) {
        self.credentialRecordId = credentialRecordId
    }
}
