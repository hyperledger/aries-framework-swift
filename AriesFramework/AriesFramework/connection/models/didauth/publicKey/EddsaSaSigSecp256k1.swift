
import Foundation

public struct EddsaSaSigSecp256k1: Codable, PublicKey {
    var id: String
    var controller: String
    var type: String = "Secp256k1VerificationKey2018"
    var publicKeyHex: String
    var value: String? {
        return publicKeyHex
    }

    private enum CodingKeys: String, CodingKey {
        case id, controller, type, publicKeyHex
    }
}
