
import Foundation

public struct ProofAttributeInfo {
    public let name: String?
    public let names: String?
    public let nonRevoked: RevocationInterval?
    public let restrictions: [AttributeFilter]?
}

extension ProofAttributeInfo: Codable {
    private enum CodingKeys: String, CodingKey {
        case name, names, nonRevoked = "non_revoked", restrictions
    }
}
