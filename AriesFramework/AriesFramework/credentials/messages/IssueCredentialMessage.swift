
import Foundation

public class IssueCredentialMessage: AgentMessage {
    public static let INDY_CREDENTIAL_ATTACHMENT_ID = "libindy-cred-0"
    public static var type: String = "https://didcomm.org/issue-credential/1.0/issue-credential"

    public var comment: String?
    public var credentialAttachments: [Attachment]

    private enum CodingKeys: String, CodingKey {
        case comment, credentialAttachments = "credentials~attach"
    }

    public init(id: String? = nil, comment: String?, credentialAttachments: [Attachment]) {
        self.comment = comment
        self.credentialAttachments = credentialAttachments
        super.init(id: id, type: IssueCredentialMessage.type)
    }

    public required init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        comment = try values.decodeIfPresent(String.self, forKey: .comment)
        credentialAttachments = try values.decode([Attachment].self, forKey: .credentialAttachments)
        try super.init(from: decoder)
    }

    public override func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encodeIfPresent(comment, forKey: .comment)
        try container.encode(credentialAttachments, forKey: .credentialAttachments)
        try super.encode(to: encoder)
    }

    public func getCredentialAttachmentById(_ id: String) -> Attachment? {
        return credentialAttachments.first { $0.id == id }
    }
}
