
import Foundation

public class OfferCredentialMessage: AgentMessage {
    public static let INDY_CREDENTIAL_OFFER_ATTACHMENT_ID = "libindy-cred-offer-0"
    public static var type: String = "https://didcomm.org/issue-credential/1.0/offer-credential"

    public var comment: String?
    public var credentialPreview: CredentialPreview
    public var offerAttachments: [Attachment]

    private enum CodingKeys: String, CodingKey {
        case comment, credentialPreview = "credential_preview", offerAttachments = "offers~attach"
    }

    public init(id: String?, comment: String?, credentialPreview: CredentialPreview, offerAttachments: [Attachment]) {
        self.comment = comment
        self.credentialPreview = credentialPreview
        self.offerAttachments = offerAttachments
        super.init(id: id, type: OfferCredentialMessage.type)
    }

    public required init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        comment = try values.decodeIfPresent(String.self, forKey: .comment)
        credentialPreview = try values.decode(CredentialPreview.self, forKey: .credentialPreview)
        offerAttachments = try values.decode([Attachment].self, forKey: .offerAttachments)
        try super.init(from: decoder)
    }

    public override func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encodeIfPresent(comment, forKey: .comment)
        try container.encode(credentialPreview, forKey: .credentialPreview)
        try container.encode(offerAttachments, forKey: .offerAttachments)
        try super.encode(to: encoder)
    }

    public func getOfferAttachmentById(_ id: String) -> Attachment? {
        return offerAttachments.first { $0.id == id }
    }

    public func getCredentialOffer() throws -> String {
        guard let attachment = getOfferAttachmentById(OfferCredentialMessage.INDY_CREDENTIAL_OFFER_ATTACHMENT_ID) else {
            throw AriesFrameworkError.frameworkError("Credential offer attachment not found")
        }
        return try attachment.getDataAsString()
    }
}
