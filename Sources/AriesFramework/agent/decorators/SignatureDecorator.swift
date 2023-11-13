
import Foundation
import os
import Askar
import Base58Swift

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
        guard var signedData = Data(base64Encoded: signatureData.base64urlToBase64()), signedData.count > 8 else {
            throw AriesFrameworkError.frameworkError("Invalid signature data")
        }

        guard let signature = Data(base64Encoded: signature.base64urlToBase64()) else {
            throw AriesFrameworkError.frameworkError("Invalid signature")
        }

        guard let singerBytes = Base58.base58Decode(signer) else {
            throw AriesFrameworkError.frameworkError("Invalid signer: \(signer)")
        }
        let signKey = try LocalKeyFactory().fromPublicBytes(alg: .ed25519, bytes: Data(singerBytes))
        let isValid = try signKey.verifySignature(message: signedData, signature: signature, sigType: nil)
        if !isValid {
            throw AriesFrameworkError.frameworkError("Signature verification failed")
        }

        // first 8 bytes are for 64 bit integer from unix epoch
        signedData = signedData.subdata(in: 8..<signedData.count)
        return signedData
    }

    func unpackConnection() async throws -> Connection {
        let signedData = try await unpackData()
        let connection = try JSONDecoder().decode(Connection.self, from: signedData)
        return connection
    }

    static func signData(data: Data, wallet: Wallet, verkey: String) async throws -> SignatureDecorator {
        var signatureData = Data(count: 8)
        signatureData.append(data)
        guard let signKey = try await wallet.session!.fetchKey(name: verkey, forUpdate: false) else {
            throw AriesFrameworkError.frameworkError("Key not found: \(verkey)")
        }
        let signature = try signKey.loadLocalKey().signMessage(message: signatureData, sigType: nil)
        let signatureType = "https://didcomm.org/signature/1.0/ed25519Sha512_single"
        let signer = verkey
        return SignatureDecorator(
            signatureType: signatureType,
            signatureData: signatureData.base64EncodedString().base64ToBase64url(),
            signer: signer,
            signature: Data(signature).base64EncodedString().base64ToBase64url())
    }
}
