
import Foundation

public enum DidDocService: Codable {
    case didDocument(DidDocumentService)
    case didComm(DidCommService)
    case indyAgent(IndyAgentService)
    case didCommV2(DidCommV2Service)

    var priority: Int {
        switch self {
        case .didDocument, .didCommV2:
            return 0
        case .didComm(let doc):
            return doc.priority ?? 0
        case .indyAgent(let doc):
            return doc.priority ?? 0
        }
    }

    var type: String {
        switch self {
        case .didDocument(let doc):
            return doc.type
        case .didComm(let doc):
            return doc.type
        case .indyAgent(let doc):
            return doc.type
        case .didCommV2(let doc):
            return doc.type
        }
    }

    var recipientKeys: [String] {
        switch self {
        case .didDocument, .didCommV2:
            return []
        case .didComm(let doc):
            return doc.recipientKeys
        case .indyAgent(let doc):
            return doc.recipientKeys
        }
    }

    var serviceEndpoint: String {
        switch self {
        case .didDocument(let doc):
            return doc.serviceEndpoint
        case .didComm(let doc):
            return doc.serviceEndpoint
        case .indyAgent(let doc):
            return doc.serviceEndpoint
        case .didCommV2(let doc):
            return doc.serviceEndpoint.uri
        }
    }

    var routingKeys: [String]? {
        switch self {
        case .didDocument:
            return []
        case .didComm(let doc):
            return doc.routingKeys
        case .indyAgent(let doc):
            return doc.routingKeys
        case .didCommV2(let doc):
            return doc.serviceEndpoint.routingKeys
        }
    }

    enum CodingKeys: String, CodingKey {
        case type
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(String.self, forKey: .type)
        switch type {
        case DidCommService.type:
            self = .didComm(try DidCommService(from: decoder))
        case IndyAgentService.type:
            self = .indyAgent(try IndyAgentService(from: decoder))
        case DidCommV2Service.type:
            self = .didCommV2(try DidCommV2Service(from: decoder))
        default:
            self = .didDocument(try DidDocumentService(from: decoder))
        }
    }

    public func encode(to encoder: Encoder) throws {
        switch self {
        case .didDocument(let didDocument):
            try didDocument.encode(to: encoder)
        case .didComm(let didComm):
            try didComm.encode(to: encoder)
        case .indyAgent(let indyAgent):
            try indyAgent.encode(to: encoder)
        case .didCommV2(let didCommV2):
            try didCommV2.encode(to: encoder)
        }
    }
}
