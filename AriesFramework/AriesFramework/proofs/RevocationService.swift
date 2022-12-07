
import Foundation
import Indy
import CollectionConcurrencyKit

enum RequestReferentType: String {
    case Attribute = "attribute"
    case Predicate = "predicate"
    case SelfAttestedAttribute = "self-attested-attribute"
}

struct ReferentCredential {
    let referent: String
    let credentialInfo: IndyCredentialInfo
    let type: RequestReferentType
}

public class RevocationService {
    let agent: Agent

    init(agent: Agent) {
        self.agent = agent
    }

    public func getRevocationRegistries(proof: PartialProof) async throws -> String {
        var revocationRegistries = [String: [String: Any]]()

        try await proof.identifiers.concurrentForEach { [self] (identifier) in
            if let revocationRegistryId = identifier.revocationRegistryId,
               let timestamp = identifier.timestamp {
                if revocationRegistries[revocationRegistryId] == nil {
                    revocationRegistries[revocationRegistryId] = [:]
                }
                if revocationRegistries[revocationRegistryId]![String(timestamp)] == nil {
                    let (revocationRegistryJson, _) = try await agent.ledgerService.getRevocationRegistry(id: revocationRegistryId, timestamp: timestamp)
                    // swiftlint:disable:next force_cast
                    let revocationRegistry = try JSONSerialization.jsonObject(with: revocationRegistryJson.data(using: .utf8)!, options: []) as! [String: Any]
                    revocationRegistries[revocationRegistryId]![String(timestamp)] = revocationRegistry
                }
            }
        }

        let revocationStatesJson = try JSONSerialization.data(withJSONObject: revocationRegistries, options: [])
        return String(data: revocationStatesJson, encoding: .utf8)!
    }

    public func getRevocationStatus(
        credentialRevocationId: String,
        revocationRegistryId: String,
        revocationInterval: RevocationInterval) async throws -> (revoked: Bool, deltaTimestamp: Int) {

        try assertRevocationInterval(revocationInterval)
        let (revocationRegistryDeltaJson, deltaTimestamp) = try await agent.ledgerService.getRevocationRegistryDelta(id: revocationRegistryId, to: revocationInterval.to!, from: revocationInterval.from ?? revocationInterval.to!)
        let revocationRegistryDelta = try JSONDecoder().decode(RevocationRegistryDelta.self, from: revocationRegistryDeltaJson.data(using: .utf8)!)

        let revoked = revocationRegistryDelta.value.revoked?.contains(credentialRevocationId) ?? false
        return (revoked, deltaTimestamp)
    }

    public func createRevocationState(proofRequestJson: String, requestedCredentials: RequestedCredentials) async throws -> String {
        var revocationStates = [String: [String: Any]]()
        var referentCredentials = [ReferentCredential]()

        for (k, v) in requestedCredentials.requestedAttributes {
            referentCredentials.append(ReferentCredential(referent: k, credentialInfo: v.credentialInfo!, type: .Attribute))
        }
        for (k, v) in requestedCredentials.requestedPredicates {
            referentCredentials.append(ReferentCredential(referent: k, credentialInfo: v.credentialInfo!, type: .Predicate))
        }

        let proofRequest = try JSONDecoder().decode(ProofRequest.self, from: proofRequestJson.data(using: .utf8)!)
        try await referentCredentials.concurrentForEach { [self] (credential) in
            let referentRevocationInterval = credential.type == .Attribute
                ? proofRequest.requestedAttributes[credential.referent]?.nonRevoked
                : proofRequest.requestedPredicates[credential.referent]?.nonRevoked
            if let requestRevocationInterval = referentRevocationInterval ?? proofRequest.nonRevoked,
               let credentialRevocationId = credential.credentialInfo.credentialRevocationId,
               let revocationRegistryId = credential.credentialInfo.revocationRegistryId {

                try assertRevocationInterval(requestRevocationInterval)

                let revocationRegistryDefinition = try await agent.ledgerService.getRevocationRegistryDefinition(id: revocationRegistryId)
                let (revocationRegistryDelta, deltaTimestamp) = try await agent.ledgerService.getRevocationRegistryDelta(id: revocationRegistryId, to: requestRevocationInterval.to!, from: 0)
                let tailsReader = try await downloadTails(revocationRegistryDefinition: revocationRegistryDefinition)

                let revocationStateJson = try await IndyAnoncreds.createRevocationState(
                    forCredRevID: credentialRevocationId,
                    timestamp: deltaTimestamp as NSNumber,
                    revRegDefJSON: revocationRegistryDefinition,
                    revRegDeltaJSON: revocationRegistryDelta,
                    blobStorageReaderHandle: tailsReader)
                // swiftlint:disable:next force_cast
                let revocationState = try JSONSerialization.jsonObject(with: revocationStateJson!.data(using: .utf8)!, options: []) as! [String: Any]

                if revocationStates[revocationRegistryId] == nil {
                    revocationStates[revocationRegistryId] = [:]
                }
                revocationStates[revocationRegistryId]![String(deltaTimestamp)] = revocationState
            }
        }

        let revocationStatesJson = try JSONSerialization.data(withJSONObject: revocationStates, options: [])
        return String(data: revocationStatesJson, encoding: .utf8)!
    }

    func assertRevocationInterval(_ requestRevocationInterval: RevocationInterval) throws {
        if requestRevocationInterval.to == nil {
            throw AriesFrameworkError.frameworkError("Presentation requests proof of non-revocation with no 'to' value specified")
        }

        if requestRevocationInterval.from != nil && requestRevocationInterval.to != requestRevocationInterval.from {
            throw AriesFrameworkError.frameworkError("Presentation requests proof of non-revocation with an interval from: '\(requestRevocationInterval.from!)' that does not match the interval to: '\(requestRevocationInterval.to!)', as specified in Aries RFC 0441")
        }
    }

    func parseRevocationRegistryDefinition(_ revocationRegistryDefinitionJson: String) throws -> (tailsLocation: String, tailsHash: String) {
        let revocationRegistryDefinition = try JSONSerialization.jsonObject(with: revocationRegistryDefinitionJson.data(using: .utf8)!, options: []) as? [String: Any]
        let value = revocationRegistryDefinition?["value"] as? [String: Any]
        guard let tailsLocation = value?["tailsLocation"] as? String, let tailsHash = value?["tailsHash"] as? String else {
            throw AriesFrameworkError.frameworkError("Could not parse tailsLocation and tailsHash from revocation registry definition")
        }
        return (tailsLocation, tailsHash)
    }

    func downloadTails(revocationRegistryDefinition: String) async throws -> NSNumber {
        let (tailsLocation, tailsHash) = try parseRevocationRegistryDefinition(revocationRegistryDefinition)
        let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let filePath = "\(documentsDirectory.path)/tails/\(tailsHash)"
        if !FileManager.default.fileExists(atPath: filePath) {
            guard let url = URL(string: tailsLocation) else {
                throw AriesFrameworkError.frameworkError("Invalid tailsLocation: \(tailsLocation)")
            }
            let tailsData = try Data(contentsOf: url)
            try tailsData.write(to: URL(fileURLWithPath: filePath))
        }

        return try await createTailsReader(filePath: filePath)
    }

    func createTailsReader(filePath: String) async throws -> NSNumber {
        let dirname = filePath.components(separatedBy: "/").dropLast().joined(separator: "/")
        let tailsReaderConfig = [ "base_dir": dirname ].toString()
        let tailsReader = try await IndyBlobStorage.openReader(withType: "default", config: tailsReaderConfig)
        return tailsReader!
    }
}
