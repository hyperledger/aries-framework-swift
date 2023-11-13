
import Foundation

public struct ProofAttribute {
    public let subProofIndex: String
    public let raw: String
    public let encoded: String
}

extension ProofAttribute: Codable {
    enum CodingKeys: String, CodingKey {
        case subProofIndex = "sub_proof_index", raw, encoded
    }
}
