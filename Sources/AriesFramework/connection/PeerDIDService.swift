
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
     Create a Peer DID with numAlgo 2 using the provided verkey.
     This function adds a service of type "did-communication" to the Peer DID.

     - Parameter verkey: the verkey to use for the Peer DID.
     - Returns: the Peer DID.
    */
    public func createPeerDID(verkey: String) async throws -> String {
        logger.debug("Creating Peer DID for verkey: \(verkey)")
        let verkeyData = Data(Base58.base58Decode(verkey)!)
        let (endpoints, routingKeys) = try await agent.mediationRecipient.getRoutingInfo()
        let didRoutingKeys = try routingKeys.map { rawKey in
            let key = try DIDParser.ConvertVerkeyToDidKey(verkey: rawKey)
            return try "\(key)#\(DIDParser.getMethodId(did: key))"
        }
        let authKey = try PeerDIDVerificationMaterial(
            format: .base58,
            key: verkeyData,
            type: .authentication(.ed25519VerificationKey2020))
        let agreementKey = try PeerDIDVerificationMaterial(
            format: .base58,
            key: verkeyData,
            type: .agreement(.x25519KeyAgreementKey2019))
        let service = [
            "id": "#service-1",
            "type": DidCommService.type,
            "serviceEndpoint": endpoints[0],
            "routingKeys": didRoutingKeys,
            "recipientKeys": [["#key-2"]]   // peerdid-swift encodes key-agreement key first.
        ] as AnyCodable
        return try PeerDIDHelper.createAlgo2(
            authenticationKeys: [authKey],
            agreementKeys: [agreementKey],
            services: [service])
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
