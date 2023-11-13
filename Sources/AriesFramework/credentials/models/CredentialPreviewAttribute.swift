
import Foundation

public struct CredentialPreviewAttribute {
    public var name: String
    public var mimeType: String?
    public var value: String
}

extension CredentialPreviewAttribute: Codable {
    enum CodingKeys: String, CodingKey {
        case name, mimeType = "mime-type", value
    }
}
