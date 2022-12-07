
import Foundation

public struct Ed25119Sig2018: Codable, PublicKey {
    var id: String
    var controller: String
    var type: String = "Ed25519VerificationKey2018"
    var publicKeyBase58: String
    var value: String? {
        return publicKeyBase58
    }

    private enum CodingKeys: String, CodingKey {
        case id, controller, type, publicKeyBase58
    }
}
