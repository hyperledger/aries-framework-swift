// swiftlint:disable cyclomatic_complexity

import Foundation
import os
import Askar
import Base58Swift

public struct DidInfo {
    let did: String
    let verkey: String

    public func getPair() -> (String, String) {
        return (did, verkey)
    }
}

public class Wallet {
    let agent: Agent
    let logger = Logger(subsystem: "AriesFramework", category: "Wallet")
    let jsonEncoder = JSONEncoder()
    let jsonDecoder = JSONDecoder()
    let storeManager = AskarStoreManager()
    let keyFactory = LocalKeyFactory()
    let crypto = AskarCrypto()
    var store: AskarStore?
    var session: AskarSession?

    /// Link secret id to identify the prover in AnonCreds. This will not be nil after the agent initialization.
    public private(set) var linkSecretId: String?
    /// Public did generated by the ``AgentConfig.publicDidSeed``.
    public private(set) var publicDid: DidInfo?

    let walletExistKey: String
    let secretIdKey: String

    init(agent: Agent) {
        self.agent = agent
        jsonEncoder.outputFormatting = .withoutEscapingSlashes

        walletExistKey = agent.agentConfig.label + " aries_framework_wallet_exist"
        secretIdKey = agent.agentConfig.label + " aries_framework_wallet_secret_id_key"
    }

    private var storePath: String {
        let documentDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        return documentDirectory.appendingPathComponent("wallet")
                                .appendingPathComponent(agent.agentConfig.walletId)
                                .appendingPathComponent("sqlite.db").path
    }

    private var storeUri: String {
        return "sqlite://" + storePath
    }

    func initialize() async throws {
        logger.info("Initializing wallet for \(self.agent.agentConfig.label)")
        if store != nil {
          logger.warning("Wallet already initialized.")
          try await close()
        }

        let userDefaults = UserDefaults.standard
        if !userDefaults.bool(forKey: walletExistKey) {
            do {
                try FileManager.default.createDirectory(atPath: (storePath as NSString).deletingLastPathComponent, withIntermediateDirectories: true, attributes: nil)
                store = try await storeManager.provision(specUri: storeUri, keyMethod: "raw", passKey: self.agent.agentConfig.walletKey, profile: nil, recreate: true)
                userDefaults.set(true, forKey: walletExistKey)
            } catch {
                throw AriesFrameworkError.frameworkError("Wallet creation failed: \(error)")
            }
        } else {
            do {
                store = try await storeManager.open(specUri: storeUri, keyMethod: "raw", passKey: self.agent.agentConfig.walletKey, profile: nil)
                userDefaults.set(true, forKey: walletExistKey)
            } catch {
                throw AriesFrameworkError.frameworkError("Wallet open failed: \(error)")
            }
        }
        session = try await store!.session(profile: nil)

        linkSecretId = userDefaults.string(forKey: secretIdKey)
        if linkSecretId == nil {
            linkSecretId = try await agent.anoncredsService.createLinkSecret()
            userDefaults.set(linkSecretId, forKey: secretIdKey)
        }
    }

    func close() async throws {
        logger.debug("Closing wallet")
        try await session?.close()
        try await store?.close()

        session = nil
        store = nil
        linkSecretId = nil
    }

    func delete() async throws {
        let userDefaults = UserDefaults.standard
        if store != nil {
            try? await close()
        }

        do {
            let removed = try await storeManager.remove(specUri: storeUri)
            if !removed {
                throw AriesFrameworkError.frameworkError("remove() returned false")
            }
        } catch {
            logger.debug("Wallet deletion failed: \(error)")
            logger.debug("Trying to delete wallet file manually...")
            try? FileManager.default.removeItem(at: URL(fileURLWithPath: storePath))
        }

        userDefaults.removeObject(forKey: walletExistKey)
        userDefaults.removeObject(forKey: secretIdKey)
    }

    public func initPublicDid(seed: String) async throws {
        let (did, verkey) = try await createDid(seed: seed)
        publicDid = DidInfo(did: did, verkey: verkey)
    }

    public func createDid(seed: String? = nil) async throws -> (String, String) {
        // Use fromSecretBytes() instead of fromSeed() for compatibility with indy-sdk
        let key = seed == nil ? try keyFactory.generate(alg: .ed25519, ephemeral: false) :
                                try keyFactory.fromSecretBytes(alg: .ed25519, bytes: seed!.data(using: .utf8)!)

        let publicKey = try key.toPublicBytes()
        let verkey = Base58.base58Encode([UInt8](publicKey))
        let did = Base58.base58Encode([UInt8](publicKey[0..<16]))
        do {
            try await session!.insertKey(name: verkey, key: key, metadata: nil, tags: nil, expiryMs: nil)
        } catch ErrorCode.Duplicate(_) {
            logger.error("createDid: Ignoring error since key already exists. verkey=\(verkey)")
        }
        logger.debug("Created DID \(did) with verkey \(verkey)")

        return (did, verkey)
    }

    public func pack(message: AgentMessage, recipientKeys: [String], senderVerkey: String?) async throws -> EncryptedMessage {
        let cek = try keyFactory.generate(alg: .c20p, ephemeral: true)
        let senderKey = senderVerkey != nil ? try await session!.fetchKey(name: senderVerkey!, forUpdate: false) : nil
        if senderVerkey != nil && senderKey == nil {
            throw AriesFrameworkError.frameworkError("Unable to pack message. Sender key \(senderVerkey!) not found in wallet.")
        }
        let senderExchangeKey = try senderKey?.loadLocalKey().convertKey(alg: .x25519)

        var recipients: [JweRecipient] = []
        for recipientKey in recipientKeys {
            guard let recipientKeyBytes = Base58.base58Decode(recipientKey) else {
                throw AriesFrameworkError.frameworkError("Invalid recipient key: \(recipientKey)")
            }
            let targetExchangeKey = try keyFactory.fromPublicBytes(alg: .ed25519, bytes: Data(recipientKeyBytes)).convertKey(alg: .x25519)
            if let senderVerkey = senderVerkey, let senderExchangeKey = senderExchangeKey {
                let encryptedSender = try crypto.boxSeal(receiverKey: targetExchangeKey, message: senderVerkey.data(using: .utf8)!)
                let nonce = try crypto.randomNonce()
                let encryptedCek = try crypto.cryptoBox(receiverKey: targetExchangeKey, senderKey: senderExchangeKey, message: cek.toSecretBytes(), nonce: nonce)

                recipients.append(JweRecipient(
                    encryptedKey: encryptedCek.base64EncodedString().base64ToBase64url(),
                    header: [
                        "kid": recipientKey,
                        "sender": encryptedSender.base64EncodedString().base64ToBase64url(),
                        "iv": nonce.base64EncodedString().base64ToBase64url()
                    ]))
            } else {
                let encryptedCek = try crypto.boxSeal(receiverKey: targetExchangeKey, message: cek.toSecretBytes())
                recipients.append(JweRecipient(
                    encryptedKey: encryptedCek.base64EncodedString().base64ToBase64url(),
                    header: [
                        "kid": recipientKey
                    ]))
            }
        }

        let protected = ProtectedHeader(
            enc: "xchacha20poly1305_ietf",
            typ: "JWM/1.0",
            alg: senderVerkey != nil ? "Authcrypt" : "Anoncrypt",
            recipients: recipients)
        let protectedData = try jsonEncoder.encode(protected)
        let buffer = try cek.aeadEncrypt(
            message: try jsonEncoder.encode(message),
            nonce: nil,
            aad: protectedData.base64EncodedString().base64ToBase64url().data(using: .utf8)!)
        let envelope = EncryptedMessage(
            protected: protectedData.base64EncodedString().base64ToBase64url(),
            iv: buffer.nonce().base64EncodedString().base64ToBase64url(),
            ciphertext: buffer.ciphertext().base64EncodedString().base64ToBase64url(),
            tag: buffer.tag().base64EncodedString().base64ToBase64url())

        return envelope
    }

    public func unpack(encryptedMessage: EncryptedMessage) async throws -> DecryptedMessageContext {
        do {
            let protected = try jsonDecoder.decode(ProtectedHeader.self, from: Data(base64Encoded: encryptedMessage.protected.base64urlToBase64())!)
            if protected.alg != "Anoncrypt" && protected.alg != "Authcrypt" {
                throw AriesFrameworkError.frameworkError("Unsupported pack algorithm: \(protected.alg)")
            }

            var senderKey, recipientKey: String?
            var payloadKey: Data?
            for recipient in protected.recipients {
                let kid = recipient.header!["kid"]
                if kid == nil {
                    throw AriesFrameworkError.frameworkError("Blank recipient key")
                }
                let sender = recipient.header!["sender"] != nil ? Data(base64Encoded: recipient.header!["sender"]!.base64urlToBase64())! : nil
                let iv = recipient.header!["iv"] != nil ? Data(base64Encoded: recipient.header!["iv"]!.base64urlToBase64())! : nil
                if sender != nil && iv == nil {
                    throw AriesFrameworkError.frameworkError("Missing IV")
                } else if sender == nil && iv != nil {
                    throw AriesFrameworkError.frameworkError("Unexpected IV")
                }
                let encryptedKey = Data(base64Encoded: recipient.encryptedKey.base64urlToBase64())!

                if let recipientKeyEntry = try await session!.fetchKey(name: kid!, forUpdate: false) {
                    recipientKey = kid
                    let recipientExchangeKey = try recipientKeyEntry.loadLocalKey().convertKey(alg: .x25519)
                    if sender != nil {
                        senderKey = String(data: try crypto.boxSealOpen(receiverKey: recipientExchangeKey, ciphertext: sender!), encoding: .utf8)
                        guard let senderKeyBytes = Base58.base58Decode(senderKey!) else {
                            throw AriesFrameworkError.frameworkError("Invalid sender key: \(senderKey!)")
                        }
                        let senderExchangeKey = try keyFactory.fromPublicBytes(alg: .ed25519, bytes: Data(senderKeyBytes)).convertKey(alg: .x25519)
                        payloadKey = try crypto.boxOpen(receiverKey: recipientExchangeKey, senderKey: senderExchangeKey, message: encryptedKey, nonce: iv!)
                    } else {
                        payloadKey = try crypto.boxSealOpen(receiverKey: recipientExchangeKey, ciphertext: encryptedKey)
                    }
                } else {
                    logger.debug("Recipient key \(kid!) not found in wallet")
                }
            }

            if senderKey == nil && protected.alg == "Authcrypt" {
                throw AriesFrameworkError.frameworkError("Sender public key not provided for Authcrypt")
            }
            guard let payloadKey = payloadKey else {
                throw AriesFrameworkError.frameworkError("No corresponding recipient key found")
            }

            let cek = try keyFactory.fromSecretBytes(alg: .c20p, bytes: payloadKey)
            let message = try cek.aeadDecrypt(
                ciphertext: Data(base64Encoded: encryptedMessage.ciphertext.base64urlToBase64())!,
                tag: Data(base64Encoded: encryptedMessage.tag.base64urlToBase64())!,
                nonce: Data(base64Encoded: encryptedMessage.iv.base64urlToBase64())!,
                aad: encryptedMessage.protected.data(using: .utf8)!)

            return DecryptedMessageContext(plaintextMessage: String(bytes: message, encoding: .utf8)!, senderKey: senderKey, recipientKey: recipientKey)
        } catch {
            throw AriesFrameworkError.frameworkError("Cannot unpack message: \(error)")
        }
    }
}
