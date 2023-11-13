
import Foundation

public class RequestPresentationMessage: AgentMessage {
    public static let INDY_PROOF_REQUEST_ATTACHMENT_ID = "libindy-request-presentation-0"
    public static var type: String = "https://didcomm.org/present-proof/1.0/request-presentation"

    public var comment: String?
    public var requestPresentationAttachments: [Attachment]

    private enum CodingKeys: String, CodingKey {
        case comment, requestPresentationAttachments = "request_presentations~attach"
    }

    public init(id: String? = nil, comment: String? = nil, requestPresentationAttachments: [Attachment]) {
        self.comment = comment
        self.requestPresentationAttachments = requestPresentationAttachments
        super.init(id: id, type: RequestPresentationMessage.type)
    }

    public required init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        comment = try values.decodeIfPresent(String.self, forKey: .comment)
        requestPresentationAttachments = try values.decode([Attachment].self, forKey: .requestPresentationAttachments)
        try super.init(from: decoder)
    }

    public override func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encodeIfPresent(comment, forKey: .comment)
        try container.encode(requestPresentationAttachments, forKey: .requestPresentationAttachments)
        try super.encode(to: encoder)
    }

    public func getRequestPresentationAttachmentById(_ id: String) -> Attachment? {
        return requestPresentationAttachments.first { $0.id == id }
    }

    public func indyProofRequest() throws -> String {
        guard let attachment = getRequestPresentationAttachmentById(RequestPresentationMessage.INDY_PROOF_REQUEST_ATTACHMENT_ID) else {
            throw AriesFrameworkError.frameworkError("Proof request attachment not found")
        }
        return try attachment.getDataAsString()
    }
}
