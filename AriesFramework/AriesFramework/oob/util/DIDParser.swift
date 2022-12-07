
import Foundation
import Base58Swift

public class DIDParser {
    static let PCT_ENCODED = "(?:%[0-9a-fA-F]{2})"
    static let ID_CHAR = "(?:[a-zA-Z0-9._-]|\(PCT_ENCODED))"
    static let METHOD = "([a-z0-9]+)"
    static let METHOD_ID = "((?:\(ID_CHAR)*:)*(\(ID_CHAR)+))"
    static let PARAM_CHAR = "[a-zA-Z0-9_.:%-]"
    static let PARAM = ";\(PARAM_CHAR)=\(PARAM_CHAR)*"
    static let PARAMS = "((\(PARAM))*)"
    static let PATH = "(/[^#?]*)?"
    static let QUERY = "([?][^#]*)?"
    static let FRAGMENT = "(#.*)?"
    static let DID_URL = "^did:\(METHOD):\(METHOD_ID)\(PARAMS)\(PATH)\(QUERY)\(FRAGMENT)$"

    static let MULTICODEC_PREFIX_ED25519: [UInt8] = [0xed, 0x01]
    static let DIDKEY_PREFIX = "did:key"
    static let BASE58_PREFIX = "z"

    public static func getMethodId(did: String) throws -> String {
        let regex = try NSRegularExpression(pattern: DID_URL, options: [])
        let matches = regex.matches(in: did, options: [], range: NSRange(location: 0, length: did.count))
        guard matches.count == 1 else {
            throw AriesFrameworkError.frameworkError("Invalid DID: \(did)")
        }
        let match = matches[0]
        let methodId = did[Range(match.range(at: 2), in: did)!]
        return String(methodId)
    }

    public static func getMethod(did: String) throws -> String {
        let regex = try NSRegularExpression(pattern: DID_URL, options: [])
        let matches = regex.matches(in: did, options: [], range: NSRange(location: 0, length: did.count))
        guard matches.count == 1 else {
            throw AriesFrameworkError.frameworkError("Invalid DID: \(did)")
        }
        let match = matches[0]
        let method = did[Range(match.range(at: 1), in: did)!]
        return String(method)
    }

    public static func ConvertVerkeysToDidKeys(verkeys: [String]) throws -> [String] {
        return try verkeys.map { verkey in
            return try ConvertVerkeyToDidKey(verkey: verkey)
        }
    }

    public static func ConvertDidKeysToVerkeys(didKeys: [String]) throws -> [String] {
        return try didKeys.map { didKey in
            return try ConvertDidKeyToVerkey(did: didKey)
        }
    }

    public static func ConvertVerkeyToDidKey(verkey: String) throws -> String {
        guard var bytes = Base58.base58Decode(verkey) else {
            throw AriesFrameworkError.frameworkError("Invalid base58 encoded verkey: \(verkey)")
        }
        bytes = MULTICODEC_PREFIX_ED25519 + bytes
        let base58PublicKey = Base58.base58Encode(bytes)
        return "\(DIDKEY_PREFIX):\(BASE58_PREFIX)\(base58PublicKey)"
    }

    public static func ConvertDidKeyToVerkey(did: String) throws -> String {
        let method = try getMethod(did: did)
        if method != "key" {
            throw AriesFrameworkError.frameworkError("Invalid DID method: \(method)")
        }

        let methodId = try getMethodId(did: did)
        return try ConvertFingerprintToVerkey(fingerprint: methodId)
    }

    public static func ConvertFingerprintToVerkey(fingerprint: String) throws -> String {
        let base58PublicKey = fingerprint.dropFirst(1)
        guard let bytes = Base58.base58Decode(String(base58PublicKey)) else {
            throw AriesFrameworkError.frameworkError("Invalid base58 encoded fingerprint: \(fingerprint)")
        }

        let codec = bytes.prefix(2)
        if Array(codec) != MULTICODEC_PREFIX_ED25519 {
            throw AriesFrameworkError.frameworkError("Invalid DID key codec: \(codec)")
        }

        let verkey = bytes.dropFirst(2)
        return Base58.base58Encode(Array(verkey))
    }
}
