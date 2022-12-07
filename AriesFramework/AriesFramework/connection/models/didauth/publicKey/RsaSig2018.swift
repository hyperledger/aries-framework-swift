
import Foundation

public struct RsaSig2018: Codable, PublicKey {
    var id: String
    var controller: String
    var type: String = "RsaVerificationKey2018"
    var publicKeyPem: String
    var value: String? {
        return publicKeyPem
    }

    private enum CodingKeys: String, CodingKey {
        case id, controller, type, publicKeyPem
    }
}
