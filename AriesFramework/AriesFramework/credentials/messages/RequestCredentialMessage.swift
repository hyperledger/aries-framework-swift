
import Foundation

public class RequestCredentialMessage: AgentMessage {
    public static let INDY_CREDENTIAL_REQUEST_ATTACHMENT_ID = "libindy-cred-request-0"
    public static var type: String = "https://didcomm.org/issue-credential/1.0/request-credential"

    public var comment: String?
    public var requestAttachments: [Attachment]

    private enum CodingKeys: String, CodingKey {
        case comment, requestAttachments = "requests~attach"
    }

    public init(id: String?, comment: String?, requestAttachments: [Attachment]) {
        self.comment = comment
        self.requestAttachments = requestAttachments
        super.init(id: id, type: RequestCredentialMessage.type)
    }

    public required init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        comment = try values.decodeIfPresent(String.self, forKey: .comment)
        requestAttachments = try values.decode([Attachment].self, forKey: .requestAttachments)
        try super.init(from: decoder)
    }

    public override func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encodeIfPresent(comment, forKey: .comment)
        try container.encode(requestAttachments, forKey: .requestAttachments)
        try super.encode(to: encoder)
    }

    public func getRequestAttachmentById(_ id: String) -> Attachment? {
        return requestAttachments.first { $0.id == id }
    }
}
