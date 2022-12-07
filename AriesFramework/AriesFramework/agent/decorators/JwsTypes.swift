
import Foundation

public struct JwsGeneralFormat {
    public var header: [String: String]?
    public var signature: String
    public var protected: String
}

extension JwsGeneralFormat: Codable {
    enum CodingKeys: String, CodingKey {
        case header, signature, protected
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        header = try container.decode([String: String].self, forKey: .header)
        signature = try container.decode(String.self, forKey: .signature)
        protected = try container.decode(String.self, forKey: .protected)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(header, forKey: .header)
        try container.encode(signature, forKey: .signature)
        try container.encode(protected, forKey: .protected)
    }
}

public struct JwsFlattenedFormat: Codable {
    public var signatures: [JwsGeneralFormat]
}

public enum Jws: Codable {
    case general(JwsGeneralFormat)
    case flattened(JwsFlattenedFormat)

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let jws = try? container.decode(JwsGeneralFormat.self) {
            self = .general(jws)
        } else {
            self = .flattened(try container.decode(JwsFlattenedFormat.self))
        }
    }

    public func encode(to encoder: Encoder) throws {
        switch self {
        case .general(let jws):
            try jws.encode(to: encoder)
        case .flattened(let jws):
            try jws.encode(to: encoder)
        }
    }
}
