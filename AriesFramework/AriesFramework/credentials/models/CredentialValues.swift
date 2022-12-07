
import Foundation
import CryptoKit
import BigInt

struct CredentialValues {
    static func convertAttributesToValues(attributes: [CredentialPreviewAttribute]) throws -> String {
        let values = attributes.reduce("") { (result, attribute) -> String in
            return result + "\"\(attribute.name)\": \(["raw": attribute.value, "encoded": encode(attribute.value)].toString()!),"
        }

        return "{ \(values.dropLast()) }"
    }

    static func encode(_ value: String) -> String {
        if isInt32(value) {
            return value
        }

        let sha256 = Data(SHA256.hash(data: value.data(using: .utf8)!))
        return BigUInt(sha256).description
    }

    static func isInt32(_ value: String) -> Bool {
        if let intValue = Int(value) {
            return intValue >= -2147483648 && intValue <= 2147483647
        }
        return false
    }

    static func checkValidEncoding(raw: String, encoded: String) -> Bool {
        return encoded == encode(raw)
    }
}
