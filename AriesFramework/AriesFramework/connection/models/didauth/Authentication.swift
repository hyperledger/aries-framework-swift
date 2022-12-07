
import Foundation

public enum Authentication: Codable {
    case embedded(EmbeddedAuthentication)
    case referenced(ReferencedAuthentication)

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let embedded = try? container.decode(EmbeddedAuthentication.self) {
            self = .embedded(embedded)
            return
        }
        if let referenced = try? container.decode(ReferencedAuthentication.self) {
            self = .referenced(referenced)
            return
        }
        throw DecodingError.dataCorruptedError(in: container, debugDescription: "Unable to decode Authentication")
    }

    public func encode(to encoder: Encoder) throws {
        switch self {
        case .embedded(let embedded):
            try embedded.encode(to: encoder)
        case .referenced(let referenced):
            try referenced.encode(to: encoder)
        }
    }
}
