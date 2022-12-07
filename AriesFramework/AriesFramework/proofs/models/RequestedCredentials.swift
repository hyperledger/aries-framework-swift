
import Foundation

public struct RequestedCredentials {
    public var requestedAttributes: [String: RequestedAttribute]
    public var requestedPredicates: [String: RequestedPredicate]
    public var selfAttestedAttributes: [String: String]
}

extension RequestedCredentials: Codable {
    enum CodingKeys: String, CodingKey {
        case requestedAttributes = "requested_attributes"
        case requestedPredicates = "requested_predicates"
        case selfAttestedAttributes = "self_attested_attributes"
    }

    public init() {
        self.requestedAttributes = [:]
        self.requestedPredicates = [:]
        self.selfAttestedAttributes = [:]
    }

    public func getCredentialIdentifiers() -> [String] {
        var credIds = Set<String>()
        for (_, attr) in requestedAttributes {
            credIds.insert(attr.credentialId)
        }
        for (_, pred) in requestedPredicates {
            credIds.insert(pred.credentialId)
        }
        return Array(credIds)
    }

    public func toString() throws -> String {
        let data = try JSONEncoder().encode(self)
        return String(data: data, encoding: .utf8)!
    }
}
