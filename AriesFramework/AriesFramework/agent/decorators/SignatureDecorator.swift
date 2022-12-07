
import Foundation
import Indy
import os

public struct SignatureDecorator {
    var signatureType: String
    var signatureData: String
    var signer: String
    var signature: String
}

extension SignatureDecorator: CustomStringConvertible {
    public var description: String {
        return "SignatureDecorator\nsignatureType: \(signatureType)\nsignatureData: \(signatureData)\nsigner: \(signer)\nsignature: \(signature)"
    }
}

extension SignatureDecorator: Codable {
    enum CodingKeys: String, CodingKey {
        case signatureType = "@type", signatureData = "sig_data", signer = "signer", signature = "signature"
    }

    func unpackData() async throws -> Data {
        var signedData = Data(base64Encoded: signatureData.base64urlToBase64(), options: [])
        if signedData == nil || signedData!.count <= 8 {
            throw AriesFrameworkError.frameworkError("Invalid signature data")
        }

        let signature = Data(base64Encoded: signature.base64urlToBase64(), options: [])
        if signature == nil {
            throw AriesFrameworkError.frameworkError("Invalid signature")
        }

        let isValid = try await IndyCrypto.verifySignature(signature, forMessage: signedData, key: signer)
        if !isValid {
            throw AriesFrameworkError.frameworkError("Signature verification failed")
        }

        // first 8 bytes are for 64 bit integer from unix epoch
        signedData = signedData!.subdata(in: 8..<signedData!.count)
        return signedData!
    }

    func unpackConnection() async throws -> Connection {
        let signedData = try await unpackData()
        let connection = try JSONDecoder().decode(Connection.self, from: signedData)
        return connection
    }

    static func signData(data: Data, wallet: Wallet, verkey: String) async throws -> SignatureDecorator {
        var signatureData = Data(count: 8)
        signatureData.append(data)
        let signature = try await IndyCrypto.signMessage(signatureData, key: verkey, walletHandle: wallet.handle!)
        let signatureType = "https://didcomm.org/signature/1.0/ed25519Sha512_single"
        let signer = verkey
        return SignatureDecorator(
            signatureType: signatureType,
            signatureData: signatureData.base64EncodedString(options: []).base64ToBase64url(),
            signer: signer,
            signature: signature!.base64EncodedString(options: []).base64ToBase64url())
    }
}
