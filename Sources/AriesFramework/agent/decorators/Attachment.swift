
import Foundation

public struct AttachmentData: Codable {
    var base64: String?
    var json: String?
    var links: [String]?
    var jws: Jws?
    var sha256: String?

    enum CodingKeys: String, CodingKey {
        case base64, json, links, jws, sha256
    }
}

public struct Attachment: Codable {
    var id: String
    var description: String?
    var filename: String?
    var mimetype: String?
    var lastModified: Date?
    var byteCount: Int?
    var data: AttachmentData

    enum CodingKeys: String, CodingKey {
        case id = "@id", description, filename, mimetype = "mime-type", lastModified = "lastmod_time", byteCount = "byte_count", data
    }

    public func getDataAsString() throws -> String {
        if let base64 = data.base64, let decoded = Data(base64Encoded: base64) {
            return String(data: decoded, encoding: .utf8)!
        } else if let json = data.json {
            return json
        } else {
            throw AriesFrameworkError.frameworkError("No attachment data found in `json` or `base64` data fields.")
        }
    }

    mutating func addJws(_ jws: JwsGeneralFormat) {
        if data.jws == nil {
            data.jws = .general(jws)
            return
        }

        switch data.jws {
        case .flattened(var flattened):
            flattened.signatures.append(jws)
        case .general(let general):
            data.jws = .flattened(JwsFlattenedFormat(signatures: [general, jws]))
        case .none: break
        }
    }

    public static func fromData(_ data: Data, id: String) -> Attachment {
        return Attachment(
            id: id,
            mimetype: "application/json",
            data: AttachmentData(base64: data.base64EncodedString()))
    }
}
