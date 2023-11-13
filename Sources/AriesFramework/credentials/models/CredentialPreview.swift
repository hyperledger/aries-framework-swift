
import Foundation

public struct CredentialPreview: Codable {
    public static let type = "https://didcomm.org/issue-credential/1.0/credential-preview"
    public var type: String
    public var attributes: [CredentialPreviewAttribute]

    private enum CodingKeys: String, CodingKey {
        case type = "@type", attributes
    }

    public init(attributes: [CredentialPreviewAttribute]) {
        self.type = CredentialPreview.type
        self.attributes = attributes
    }

    public static func fromDictionary(_ dic: [String: String]) -> CredentialPreview {
        let attributes = dic.map { (key, value) -> CredentialPreviewAttribute in
            return CredentialPreviewAttribute(name: key, mimeType: "text/plain", value: value)
        }
        return CredentialPreview(attributes: attributes)
    }
}
