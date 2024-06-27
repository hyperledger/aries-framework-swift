import Foundation

public struct ProofAttributeInfo {
    public init(name: String? = nil, names: [String]? = nil, nonRevoked: RevocationInterval? = nil, restrictions: [AttributeFilter]? = nil) {
        self.name = name
        self.names = names
        self.nonRevoked = nonRevoked
        self.restrictions = restrictions
    }
    
    public let name: String?
    public let names: [String]?
    public let nonRevoked: RevocationInterval?
    public let restrictions: [AttributeFilter]?
}

extension ProofAttributeInfo: Codable {
    private enum CodingKeys: String, CodingKey {
        case name, names, nonRevoked = "non_revoked", restrictions
    }
}
