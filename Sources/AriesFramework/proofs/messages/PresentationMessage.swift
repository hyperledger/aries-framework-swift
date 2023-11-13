
import Foundation

public class PresentationMessage: AgentMessage {
    public static let INDY_PROOF_ATTACHMENT_ID = "libindy-presentation-0"
    public static var type: String = "https://didcomm.org/present-proof/1.0/presentation"

    public var comment: String?
    public var presentationAttachments: [Attachment]

    private enum CodingKeys: String, CodingKey {
        case comment, presentationAttachments = "presentations~attach"
    }

    public init(id: String? = nil, comment: String? = nil, presentationAttachments: [Attachment]) {
        self.comment = comment
        self.presentationAttachments = presentationAttachments
        super.init(id: id, type: PresentationMessage.type)
    }

    public required init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        comment = try values.decodeIfPresent(String.self, forKey: .comment)
        presentationAttachments = try values.decode([Attachment].self, forKey: .presentationAttachments)
        try super.init(from: decoder)
    }

    public override func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encodeIfPresent(comment, forKey: .comment)
        try container.encode(presentationAttachments, forKey: .presentationAttachments)
        try super.encode(to: encoder)
    }

    public func getPresentationAttachmentById(_ id: String) -> Attachment? {
        return presentationAttachments.first { $0.id == id }
    }

    public func indyProof() throws -> String {
        guard let attachment = getPresentationAttachmentById(PresentationMessage.INDY_PROOF_ATTACHMENT_ID) else {
            throw AriesFrameworkError.frameworkError("Proof attachment not found")
        }
        return try attachment.getDataAsString()
    }
}
