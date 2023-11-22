
import Foundation
import Anoncreds
import CollectionConcurrencyKit
import os

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
    let logger = Logger(subsystem: "AriesFramework", category: "RevocationService")

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

    public func getRevocationStatusLists(proof: PartialProof, revocationRegistryDefinitions: [String: RevocationRegistryDefinition]) async throws -> [Anoncreds.RevocationStatusList] {
        var revocationStatusLists = [Anoncreds.RevocationStatusList]()
        try await proof.identifiers.concurrentForEach { [self] (identifier) in
            if let revocationRegistryId = identifier.revocationRegistryId,
               let timestamp = identifier.timestamp {
                guard let revocationRegistryDefinition = revocationRegistryDefinitions[revocationRegistryId] else {
                    throw AriesFrameworkError.frameworkError("Revocation registry definition not found for id: \(revocationRegistryId)")
                }
                let (revocationRegistryJson, _) = try await agent.ledgerService.getRevocationRegistry(id: revocationRegistryId, timestamp: timestamp)
                let revocationRegistry = try JSONDecoder().decode(RevocationRegistryDelta.self, from: revocationRegistryJson.data(using: .utf8)!)
                let revocationStatusList = RevocationStatusList(
                    issuerId: revocationRegistryDefinition.issuerId(),
                    currentAccumulator: revocationRegistry.accum,
                    revRegDefId: revocationRegistryId,
                    revocationList: [],
                    timestamp: timestamp)
                revocationStatusLists.append(try Anoncreds.RevocationStatusList(json: revocationStatusList.toString()))
            }
        }
        return revocationStatusLists
    }

    public func getRevocationStatus(
        credentialRevocationId: String,
        revocationRegistryId: String,
        revocationInterval: RevocationInterval) async throws -> (revoked: Bool, deltaTimestamp: Int) {

        try assertRevocationInterval(revocationInterval)
        let (revocationRegistryDeltaJson, deltaTimestamp) = try await agent.ledgerService.getRevocationRegistryDelta(id: revocationRegistryId, to: revocationInterval.to!, from: 0)
        let revocationRegistryDelta = try JSONDecoder().decode(RevocationRegistryDelta.self, from: revocationRegistryDeltaJson.data(using: .utf8)!)
        guard let credentialRevocationId = Int(credentialRevocationId) else {
            throw AriesFrameworkError.frameworkError("credentialRevocationId conversion to Int failed.")
        }
        let revoked = revocationRegistryDelta.revoked?.contains(credentialRevocationId) ?? false
        return (revoked, deltaTimestamp)
    }

    public func createRevocationState(credential: Credential, timestamp: Int) async throws -> CredentialRevocationState {
        guard let credentialRevocationId = credential.revRegIndex(),
              let revocationRegistryId = credential.revRegId() else {
            throw AriesFrameworkError.frameworkError("Credential does not have revocation information.")
        }

        let revocationRegistryDefinition = try RevocationRegistryDefinition(json: try await agent.ledgerService.getRevocationRegistryDefinition(id: revocationRegistryId))
        let (revocationRegistryDelta, deltaTimestamp) = try await agent.ledgerService.getRevocationRegistryDelta(id: revocationRegistryId, to: timestamp, from: 0)
        let tailsFile = try downloadTails(revocationRegistryDefinition: revocationRegistryDefinition)

        let revocationState = try Prover().createRevocationState(
            revRegDef: revocationRegistryDefinition,
            revRegDelta: Anoncreds.RevocationRegistryDelta(json: revocationRegistryDelta),
            timestamp: UInt64(deltaTimestamp),
            revRegIdx: UInt32(credentialRevocationId),
            tailsPath: tailsFile.path)
        return revocationState
    }

    public func createRevocationStates(proofRequestJson: String, requestedCredentials: RequestedCredentials) async throws -> String {
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

                let revocationRegistryDefinition = try RevocationRegistryDefinition(json: try await agent.ledgerService.getRevocationRegistryDefinition(id: revocationRegistryId))
                let (revocationRegistryDelta, deltaTimestamp) = try await agent.ledgerService.getRevocationRegistryDelta(id: revocationRegistryId, to: requestRevocationInterval.to!, from: 0)
                let tailsFile = try await downloadTails(revocationRegistryDefinition: revocationRegistryDefinition)

                let revocationState = try Prover().createRevocationState(
                    revRegDef: revocationRegistryDefinition,
                    revRegDelta: Anoncreds.RevocationRegistryDelta(json: revocationRegistryDelta),
                    timestamp: UInt64(deltaTimestamp),
                    revRegIdx: UInt32(credentialRevocationId)!,
                    tailsPath: tailsFile.path)
                // swiftlint:disable:next force_cast
                let revocationStateObj = try JSONSerialization.jsonObject(with: revocationState.toJson().data(using: .utf8)!, options: []) as! [String: Any]

                if revocationStates[revocationRegistryId] == nil {
                    revocationStates[revocationRegistryId] = [:]
                }
                revocationStates[revocationRegistryId]![String(deltaTimestamp)] = revocationStateObj
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

    func downloadTails(revocationRegistryDefinition: RevocationRegistryDefinition) throws -> URL {
        logger.debug("Downloading tails file for revocation registry definition: \(revocationRegistryDefinition.revRegId())")
        let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let tailsFolderPath = documentsDirectory.appendingPathComponent("tails")
        if !FileManager.default.fileExists(atPath: tailsFolderPath.path) {
            try FileManager.default.createDirectory(at: tailsFolderPath, withIntermediateDirectories: true)
        }

        let tailsFilePath = tailsFolderPath.appendingPathComponent(revocationRegistryDefinition.tailsHash())
        if !FileManager.default.fileExists(atPath: tailsFilePath.path) {
            let tailsLocation = revocationRegistryDefinition.tailsLocation()
            let url = tailsLocation.hasPrefix("http")
                ? URL(string: tailsLocation)
                : URL(fileURLWithPath: tailsLocation)
            guard let url = url else {
                throw AriesFrameworkError.frameworkError("Invalid tailsLocation: \(tailsLocation)")
            }
            logger.debug("Downloading tails file from: \(url)")
            let tailsData = try Data(contentsOf: url)
            try tailsData.write(to: URL(fileURLWithPath: tailsFilePath.path))
        }

        return tailsFilePath
    }
}
