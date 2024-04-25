
import Foundation
import os
import Base58Swift

public class JwsService {
    let agent: Agent
    let logger = Logger(subsystem: "AriesFramework", category: "JwsService")

    init(agent: Agent) {
        self.agent = agent
    }

    /**
     Creates a JWS using the given payload and verkey.

     - Parameters:
       - payload: The payload to sign.
       - verkey: The verkey to sign the payload for. The verkey should be created using ``Wallet.createDid(seed:)``.
     - Returns: A JWS object.
    */
    public func createJws(payload: Data, verkey: String) async throws -> JwsGeneralFormat {
        guard let keyEntry = try await agent.wallet.session!.fetchKey(name: verkey, forUpdate: false) else {
            throw AriesFrameworkError.frameworkError("Unable to find key for verkey: \(verkey)")
        }
        let key = try keyEntry.loadLocalKey()
        let jwk = try JSONSerialization.jsonObject(with: key.toJwkPublic(alg: nil).data(using: .utf8)!) as! [String: Any]
        let protectedHeader = [
            "alg": "EdDSA",
            "jwk": jwk
        ] as [String: Any]
        let protectedHeaderJson = try JSONSerialization.data(withJSONObject: protectedHeader)
        let base64ProtectedHeader = protectedHeaderJson.base64EncodedString().base64ToBase64url()
        let base64Payload = payload.base64EncodedString().base64ToBase64url()

        let message = "\(base64ProtectedHeader).\(base64Payload)".data(using: .utf8)!
        let signature = try key.signMessage(message: message, sigType: nil)
        let base64Signature = signature.base64EncodedString().base64ToBase64url()
        let header = [
            "kid": try DIDParser.ConvertVerkeyToDidKey(verkey: verkey)
        ]

        return JwsGeneralFormat(header: header, signature: base64Signature, protected: base64ProtectedHeader)
    }

    /**
     Verifies the given JWS against the given payload.

     - Parameters:
       - jws: The JWS to verify. This should be General JWS JSON Serialization Syntax.
       - payload: The payload to verify the JWS against.
     - Returns: A tuple containing the validity of the JWS and the signer's verkey.
    */
    public func verifyJws(jws: Jws, payload: Data) async throws -> (isValid: Bool, signer: String) {
        logger.debug("Verifying JWS...")
        guard case let .general(jws) = jws else {
            throw AriesFrameworkError.frameworkError("Verifying multiple JWS not supported")
        }
        guard let protectedJson = Data(base64Encoded: jws.protected.base64urlToBase64()),
              let protected = try JSONSerialization.jsonObject(with: protectedJson) as? [String: Any],
              let signature = Data(base64Encoded: jws.signature.base64urlToBase64()),
              let jwk = protected["jwk"] else {
            throw AriesFrameworkError.frameworkError("Invalid Jws: \(jws)")
        }
        let jwkData = try JSONSerialization.data(withJSONObject: jwk)
        let jwkString = String(data: jwkData, encoding: .utf8)!
        logger.debug("jwk: \(jwkString)")
        let key = try agent.wallet.keyFactory.fromJwk(jwk: jwkString)
        let publicBytes = try key.toPublicBytes()
        let signer = Base58.base58Encode([UInt8](publicBytes))

        let base64Payload = payload.base64EncodedString().base64ToBase64url()
        let message = "\(jws.protected).\(base64Payload)".data(using: .utf8)!
        let isValid = try key.verifySignature(message: message, signature: signature, sigType: nil)

        return (isValid, signer)
    }
}
