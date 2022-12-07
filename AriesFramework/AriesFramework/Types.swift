
import Foundation

public typealias Tags = [String: String]

public extension Tags {
    static func stringFromArray(_ array: [String]) -> String? {
        // swiftlint:disable:next force_try
        return String(data: try! JSONEncoder().encode(array), encoding: .utf8) ?? nil
    }

    func toString() -> String {
        // swiftlint:disable:next force_try
        return String(data: try! JSONEncoder().encode(self), encoding: .utf8) ?? "{}"
    }
}

public extension String {
    func base64urlToBase64() -> String {
        var base64 = self
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")
        if base64.count % 4 != 0 {
            base64.append(String(repeating: "=", count: 4 - base64.count % 4))
        }
        return base64
    }

    func base64ToBase64url() -> String {
        let base64url = self
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
        return base64url
    }
}

public extension Array {
    func toString() -> String {
        // swiftlint:disable:next force_try
        let jsonData = try! JSONSerialization.data(withJSONObject: self)
        return String(data: jsonData, encoding: .utf8) ?? "[]"
    }
}

public enum DidCommMimeType: String {
    case V0 = "application/ssi-agent-wire"
    case V1 = "application/didcomm-envelope-enc"
}

public enum AckStatus: String, Codable {
    case OK
    case FAIL
    case PENDING
}

public struct OutboundPackage: Codable {
    let payload: EncryptedMessage
    let responseRequested: Bool
    let endpoint: String
    let connectionId: String?
}

public struct OutboundMessage {
    var payload: AgentMessage
    var connection: ConnectionRecord
}

public struct EncryptedMessage: Codable {
    let protected: String
    let iv: String
    let ciphertext: String
    let tag: String
}

public struct EnvelopeKeys {
    let recipientKeys: [String]
    let routingKeys: [String]
    let senderKey: String?
}

public struct DecryptedMessageContext: Codable {
    let plaintextMessage: String
    let senderKey: String?
    let recipientKey: String?

    enum CodingKeys: String, CodingKey {
        case plaintextMessage = "message", senderKey = "sender_verkey", recipientKey = "recipient_verkey"
    }
}

public struct InboundMessageContext {
    let message: AgentMessage
    let plaintextMessage: String
    let connection: ConnectionRecord?
    let senderVerkey: String?
    let recipientVerkey: String?

    func assertReadyConnection() throws -> ConnectionRecord {
        if connection == nil {
            throw AriesFrameworkError.frameworkError("No connection associated with incoming message \(message.type)")
        }
        try connection!.assertReady()
        return connection!
    }
}
