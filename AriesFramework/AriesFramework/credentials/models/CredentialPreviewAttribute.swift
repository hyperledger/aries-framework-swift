
import Foundation

public struct CredentialPreviewAttribute {
    public var name: String
    public var mimeType: String
    public var value: String

    public init(name: String, value: String, mimeType: String = "text/plain") {
        self.mimeType = mimeType
        self.name = name
        self.value = value
    }
}

extension CredentialPreviewAttribute: Codable {
    enum CodingKeys: String, CodingKey {
        case name, mimeType = "mime-type", value
    }
}
