
import Foundation
import os
import DIDCore
import PeerDID
import Base58Swift

public class PeerDIDService {
    let agent: Agent
    let logger = Logger(subsystem: "AriesFramework", category: "PeerDIDService")

    init(agent: Agent) {
        self.agent = agent
    }

    /**
     Create a Peer DID numAlgo 2 for the given verkey.

     - Parameter verkey: the verkey to use for the Peer DID.
     - Returns: the Peer DID.
    */
    public func createPeerDID(verkey: String) async throws -> String {
        logger.debug("Creating Peer DID for verkey: \(verkey)")
        let verkey = Data(Base58.base58Decode(verkey)!)
        
        let (endpoints, routingKeys) = try await agent.mediationRecipient.getRoutingInfo()
        let didRoutingKeys = try DIDParser.ConvertVerkeysToDidKeys(verkeys: routingKeys)
        let authKey = try PeerDIDVerificationMaterial(
            format: .base58,
            key: verkey,
            type: .authentication(.ed25519VerificationKey2020))
        let agreementKey = try PeerDIDVerificationMaterial(
            format: .base58,
            key: verkey,
            type: .agreement(.x25519KeyAgreementKey2020))
        let service = DIDDocument.Service(
            id: "#IndyAgentService",
            type: "DIDCommMessaging",
            serviceEndpoint: AnyCodable(dictionaryLiteral: ("uri", endpoints[0]), ("routingKeys", didRoutingKeys)))
        return try PeerDIDHelper.createAlgo2(
            authenticationKeys: [authKey],
            agreementKeys: [agreementKey],
            services: [service],
            recipientKeys: [[]])
            .string
    }

    /**
     Parse a Peer DID into a DidDoc. Only numAlgo 0 and 2 are supported.
     In case of numAlgo 2 DID, the routing keys should be did:key format.

     - Parameter did: the Peer DID to parse.
     - Returns: the parsed DID Document.
    */
    public func parsePeerDID(_ did: String) throws -> DidDoc {
        logger.debug("Parsing Peer DID: \(did)")
        let didDocument = try PeerDIDHelper.resolve(peerDIDStr: did)
        return try DidDoc(from: didDocument)
    }
}
