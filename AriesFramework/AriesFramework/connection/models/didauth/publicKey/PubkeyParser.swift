
import Foundation

public struct PubkeyParser: Decodable {
    var pubkeys: [PublicKey]
    public init(from decoder: Decoder) throws {
        pubkeys = []
        var container = try decoder.unkeyedContainer()
        while !container.isAtEnd {
            if let item = try? container.decodeIfPresent(RsaSig2018.self) {
                pubkeys.append(item)
            }
            if let item = try? container.decodeIfPresent(Ed25119Sig2018.self) {
                pubkeys.append(item)
            }
            if let item = try? container.decodeIfPresent(EddsaSaSigSecp256k1.self) {
                pubkeys.append(item)
            }
        }
    }
}
