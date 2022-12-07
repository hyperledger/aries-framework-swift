
import Foundation

public struct EmbeddedAuthentication: Codable {
    var publicKey: PublicKey

    enum CodingKeys: String, CodingKey {
        case type
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(String.self, forKey: .type)
        switch type {
        case "RsaVerificationKey2018":
            publicKey = try RsaSig2018(from: decoder)
        case "Ed25519VerificationKey2018":
            publicKey = try Ed25119Sig2018(from: decoder)
        case "Secp256k1VerificationKey2018":
            publicKey = try EddsaSaSigSecp256k1(from: decoder)
        default:
            throw DecodingError.dataCorruptedError(forKey: .type, in: container, debugDescription: "Unable to decode EmbeddedAuthentication")
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch publicKey {
        case let rsa as RsaSig2018:
            try container.encode(rsa)
        case let ed25519 as Ed25119Sig2018:
            try container.encode(ed25519)
        case let eddsa as EddsaSaSigSecp256k1:
            try container.encode(eddsa)
        default:
            throw EncodingError.invalidValue(publicKey, EncodingError.Context(codingPath: [], debugDescription: "Unable to encode EmbeddedAuthentication"))
        }
    }
}
