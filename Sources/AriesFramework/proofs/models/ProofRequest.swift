
import Foundation

public struct ProofRequest {
    public let name: String
    public let version: String
    public let nonce: String
    public let requestedAttributes: [String: ProofAttributeInfo]
    public let requestedPredicates: [String: ProofPredicateInfo]
    public let nonRevoked: RevocationInterval?
    public let ver: String?
}

extension ProofRequest: Codable {
    private enum CodingKeys: String, CodingKey {
        case name, version, nonce, requestedAttributes = "requested_attributes", requestedPredicates = "requested_predicates", nonRevoked = "non_revoked", ver
    }

    public func toString() throws -> String {
        let data = try JSONEncoder().encode(self)
        return String(data: data, encoding: .utf8)!
    }

    public init(name: String? = nil, version: String? = nil, nonce: String, requestedAttributes: [String: ProofAttributeInfo], requestedPredicates: [String: ProofPredicateInfo], nonRevoked: RevocationInterval? = nil, ver: String? = nil) {
        self.name = name ?? "proof-request"
        self.version = version ?? "1.0"
        self.nonce = nonce
        self.requestedAttributes = requestedAttributes
        self.requestedPredicates = requestedPredicates
        self.nonRevoked = nonRevoked
        self.ver = ver
    }
}
