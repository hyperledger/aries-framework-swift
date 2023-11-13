
import Foundation

public struct RequestedProof {
    public let revealedAttributes: [String: ProofAttribute]
    public let selfAttestedAttributes: [String: String]
}

extension RequestedProof: Codable {
    enum CodingKeys: String, CodingKey {
        case revealedAttributes = "revealed_attrs"
        case selfAttestedAttributes = "self_attested_attrs"
    }
}
