
import Foundation
import DIDCore

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

    public init(from didDocument: DIDDocument) throws {
        let decoder = JSONDecoder()
        id = didDocument.id
        guard let type = didDocument.verificationMethods.first?.type else {
            throw AriesFrameworkError.frameworkError("No verification method found in DIDDocument")
        }
        let keyType = decoder.decode(KnownVerificationMaterialType.self, from: type.data(using: .utf8)!)
        let recipientKey = didDocument.verificationMethods.first!.material.convertToBase58(type: keyType)
        service = didDocument.services.compactMap { service in
            guard let endpoint = service.serviceEndpoint.get<ServiceEndpoint>() else {
                return nil
            }
            let routingKeys = endpoint.routingKeys?.map { try DIDParser.ConvertDIDToVerkey(did: $0) } ?? []
            DidDocService.didComm(DidCommService(
                id: service.id,
                serviceEndpoint: service.uri,
                recipientKeys: [recipientKey],
                routingKeys: routingKeys))
        }
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
