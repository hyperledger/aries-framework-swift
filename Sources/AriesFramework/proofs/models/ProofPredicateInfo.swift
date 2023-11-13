
import Foundation

public enum PredicateType: String, Codable {
    case LessThan = "<"
    case LessThanOrEqualTo = "<="
    case GreaterThan = ">"
    case GreaterThanOrEqualTo = ">="
}

public struct ProofPredicateInfo {
    public let name: String
    public let nonRevoked: RevocationInterval?
    public let predicateType: PredicateType
    public let predicateValue: Int
    public let restrictions: [AttributeFilter]?
}

extension ProofPredicateInfo: Codable {
    private enum CodingKeys: String, CodingKey {
        case name, nonRevoked = "non_revoked", restrictions, predicateType = "p_type", predicateValue = "p_value"
    }

    func asProofAttributeInfo() -> ProofAttributeInfo {
        return ProofAttributeInfo(name: name, names: nil, nonRevoked: nonRevoked, restrictions: restrictions)
    }
}
