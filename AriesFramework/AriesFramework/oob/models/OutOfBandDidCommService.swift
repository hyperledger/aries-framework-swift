
import Foundation

public enum OutOfBandDidCommService: Codable {
    case oobDidDocument(OutOfBandDidDocumentService)
    case did(String)

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let did = try? container.decode(String.self) {
            self = .did(did)
        } else {
            self = .oobDidDocument(try container.decode(OutOfBandDidDocumentService.self))
        }
    }

    public func encode(to encoder: Encoder) throws {
        switch self {
        case .oobDidDocument(let oobDidDocument):
            try oobDidDocument.encode(to: encoder)
        case .did(let did):
            try did.encode(to: encoder)
        }
    }

    public func asDidDocService() throws -> DidDocService? {
        switch self {
        case .oobDidDocument(let oobDidDocument):
            let service = DidCommService(
                id: oobDidDocument.id,
                serviceEndpoint: oobDidDocument.serviceEndpoint,
                recipientKeys: try DIDParser.ConvertDidKeysToVerkeys(didKeys: oobDidDocument.recipientKeys),
                routingKeys: try DIDParser.ConvertDidKeysToVerkeys(didKeys: oobDidDocument.routingKeys ?? []))
            return DidDocService.didComm(service)
        case .did:
            return nil
        }
    }
}

public struct OutOfBandDidDocumentService: Codable {
    var id: String
    var type: String = OutOfBandDidDocumentService.type
    var serviceEndpoint: String
    var recipientKeys: [String]
    var routingKeys: [String]?
    var accept: [String]?
    public static var type = "did-communication"
}
