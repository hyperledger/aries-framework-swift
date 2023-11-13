
import Foundation

public struct DidDoc {
    var context: String = "https://w3id.org/did/v1"
    var id: String
    var publicKey: [PublicKey]
    var service: [DidDocService]
    var authentication: [Authentication]
}

extension DidDoc: Codable {
    enum CodingKeys: String, CodingKey {
        case context = "@context", id, publicKey, service, authentication
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        service = try container.decode([DidDocService].self, forKey: .service)
        authentication = try container.decode([Authentication].self, forKey: .authentication)

        let pubkeyParser = try container.decode(PubkeyParser.self, forKey: .publicKey)
        publicKey = pubkeyParser.pubkeys
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(service, forKey: .service)
        try container.encode(authentication, forKey: .authentication)

        var pubkeyContainer = container.nestedUnkeyedContainer(forKey: .publicKey)
        for pubkey in publicKey {
            switch pubkey {
            case let rsa as RsaSig2018:
                try pubkeyContainer.encode(rsa)
            case let ed25519 as Ed25119Sig2018:
                try pubkeyContainer.encode(ed25519)
            case let eddsa as EddsaSaSigSecp256k1:
                try pubkeyContainer.encode(eddsa)
            default:
                break
            }
        }
    }

    func publicKey(id: String) -> PublicKey? {
        return publicKey.first { $0.id == id }
    }

    func servicesByType(type: String) -> [DidDocService] {
        return service.filter { $0.type == type }
    }

    func didCommServices() -> [DidDocService] {
        let services = service.filter { $0.type == DidCommService.type || $0.type == IndyAgentService.type }

        // Sort services based on indicated priority
        return services.sorted {
            $0.priority > $1.priority
        }
    }
}
