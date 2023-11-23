
import Foundation
import Anoncreds
import os
import CollectionConcurrencyKit

public class ProofService {
    let agent: Agent
    let logger = Logger(subsystem: "AriesFramework", category: "ProofService")
    let revocationService: RevocationService

    init(agent: Agent) {
        self.agent = agent
        revocationService = agent.revocationService
    }

    /**
     Create a new ``RequestPresentationMessage``.

     - Parameters:
        - proofRequest: the proof request template.
        - connectionRecord: the connection for which to create the presentation request.
        - comment: A comment to include in the presentation request.
        - autoAcceptProof: whether to automatically accept the presentation.
     - Returns: the presentation request message and a new proof record for the proof exchange.
    */
    public func createRequest(
        proofRequest: ProofRequest,
        connectionRecord: ConnectionRecord,
        comment: String? = nil,
        autoAcceptProof: AutoAcceptProof? = nil
    ) async throws -> (message: RequestPresentationMessage, record: ProofExchangeRecord) {
        try connectionRecord.assertReady()

        let proofRequestJson = try JSONEncoder().encode(proofRequest)
        let attachment = Attachment.fromData(proofRequestJson, id: RequestPresentationMessage.INDY_PROOF_REQUEST_ATTACHMENT_ID)
        let message = RequestPresentationMessage(comment: comment, requestPresentationAttachments: [attachment])

        let proofRecord = ProofExchangeRecord(
            connectionId: connectionRecord.id,
            threadId: message.threadId,
            state: .RequestSent,
            autoAcceptProof: autoAcceptProof)

        try await agent.didCommMessageRepository.saveAgentMessage(
            role: .Sender,
            agentMessage: message,
            associatedRecordId: proofRecord.id)

        try await agent.proofRepository.save(proofRecord)
        agent.agentDelegate?.onProofStateChanged(proofRecord: proofRecord)

        return (message, proofRecord)
    }

    /**
     Process a received ``RequestPresentationMessage``. This will not accept the presentation request
     or send a presentation. It will only create a new, or update the existing proof record with
     the information from the presentation request message. Use  ``createPresentation(proofRecord:requestedCredentials:comment:)``
     after calling this method to create a presentation.

     - Parameters messageContext: the message context containing a presentation request message.
     - Returns: proof record associated with the presentation request message.
    */
    public func processRequest(messageContext: InboundMessageContext) async throws -> ProofExchangeRecord {
        let proofRequestMessage = try JSONDecoder().decode(RequestPresentationMessage.self, from: Data(messageContext.plaintextMessage.utf8))

        let connection = try messageContext.assertReadyConnection()
        let proofRecord = ProofExchangeRecord(
            connectionId: connection.id,
            threadId: proofRequestMessage.threadId,
            state: .RequestReceived)

        try await agent.didCommMessageRepository.saveAgentMessage(
            role: .Receiver,
            agentMessage: proofRequestMessage,
            associatedRecordId: proofRecord.id)

        try await agent.proofRepository.save(proofRecord)
        agent.agentDelegate?.onProofStateChanged(proofRecord: proofRecord)

        return proofRecord
    }

    /**
     Create a ``PresentationMessage`` as response to a received presentation request.

     - Parameters:
        - proofRecord: the proof record for which to create the presentation.
        - requestedCredentials: the requested credentials object specifying which credentials to use for the proof
        - comment: a comment to include in the presentation.
     - Returns: the presentation message and an associated proof record.
    */
    public func createPresentation(
        proofRecord: ProofExchangeRecord,
        requestedCredentials: RequestedCredentials,
        comment: String? = nil) async throws -> (message: PresentationMessage, record: ProofExchangeRecord) {

        var proofRecord = proofRecord
        try proofRecord.assertState(.RequestReceived)

        let proofRequestMessageJson = try await agent.didCommMessageRepository.getAgentMessage(
            associatedRecordId: proofRecord.id,
            messageType: RequestPresentationMessage.type)
        let proofRequestMessage = try JSONDecoder().decode(RequestPresentationMessage.self, from: proofRequestMessageJson.data(using: .utf8)!)

        let proof = try await createProof(
            proofRequest: proofRequestMessage.indyProofRequest(),
            requestedCredentials: requestedCredentials)

        let attachment = Attachment.fromData(proof, id: PresentationMessage.INDY_PROOF_ATTACHMENT_ID)
        let presentationMessage = PresentationMessage(comment: comment, presentationAttachments: [attachment])
        presentationMessage.thread = ThreadDecorator(threadId: proofRecord.threadId)

        try await agent.didCommMessageRepository.saveAgentMessage(
            role: .Sender,
            agentMessage: presentationMessage,
            associatedRecordId: proofRecord.id)
        try await updateState(proofRecord: &proofRecord, newState: .PresentationSent)

        return (presentationMessage, proofRecord)
    }

    /**
     Process a received ``PresentationMessage``. This will not accept the presentation
     or send a presentation acknowledgement. It will only update the existing proof record with
     the information from the presentation message. Use  ``createAck(proofRecord:)``
     after calling this method to create a presentation acknowledgement.

     - Parameters messageContext: the message context containing a presentation message.
     - Returns: proof record associated with the presentation message.
    */
    public func processPresentation(messageContext: InboundMessageContext) async throws -> ProofExchangeRecord {
        let presentationMessage = try JSONDecoder().decode(PresentationMessage.self, from: Data(messageContext.plaintextMessage.utf8))
        let connection = try messageContext.assertReadyConnection()

        var proofRecord = try await agent.proofRepository.getByThreadAndConnectionId(
            threadId: presentationMessage.threadId,
            connectionId: connection.id)
        try proofRecord.assertState(.RequestSent)

        let indyProofJson = try presentationMessage.indyProof()
        let requestMessageJson = try await agent.didCommMessageRepository.getAgentMessage(
            associatedRecordId: proofRecord.id,
            messageType: RequestPresentationMessage.type)
        let requestMessage = try JSONDecoder().decode(RequestPresentationMessage.self, from: requestMessageJson.data(using: .utf8)!)
        let indyProofRequest = try requestMessage.indyProofRequest()

        proofRecord.isVerified = try await verifyProof(proofRequest: indyProofRequest, proof: indyProofJson)

        try await agent.didCommMessageRepository.saveAgentMessage(
            role: .Receiver,
            agentMessage: presentationMessage,
            associatedRecordId: proofRecord.id)
        try await updateState(proofRecord: &proofRecord, newState: .PresentationReceived)

        return proofRecord
    }

    /**
     Create a ``PresentationAckMessage`` as response to a received presentation.

     - Parameters proofRecord: the proof record for which to create the presentation acknowledgement.
     - Returns: the presentation acknowledgement message and an associated proof record.
    */
    public func createAck(proofRecord: ProofExchangeRecord) async throws -> (message: PresentationAckMessage, record: ProofExchangeRecord) {
        var proofRecord = proofRecord
        try proofRecord.assertState(.PresentationReceived)

        let ackMessage = PresentationAckMessage(threadId: proofRecord.threadId, status: .OK)
        try await updateState(proofRecord: &proofRecord, newState: .Done)

        return (ackMessage, proofRecord)
    }

    /**
     Process a received ``PresentationAckMessage``.

     - Parameters messageContext: the message context containing a presentation acknowledgement message.
     - Returns: proof record associated with the presentation acknowledgement message.
    */
    public func processAck(messageContext: InboundMessageContext) async throws -> ProofExchangeRecord {
        let ackMessage = try JSONDecoder().decode(PresentationAckMessage.self, from: Data(messageContext.plaintextMessage.utf8))
        let connection = try messageContext.assertReadyConnection()

        var proofRecord = try await agent.proofRepository.getByThreadAndConnectionId(
            threadId: ackMessage.threadId,
            connectionId: connection.id)
        try proofRecord.assertState(.PresentationSent)

        try await updateState(proofRecord: &proofRecord, newState: .Done)

        return proofRecord
    }

    /**
     Generates 80-bit numbers that can be used as a nonce for proof request.

     - Returns: generated number as a string.
    */
    public static func generateProofRequestNonce() throws -> String {
        return try Verifier().generateNonce()
    }

    /**
     Create a ``RetrievedCredentials`` object. Given input proof request,
     use credentials in the wallet to build indy requested credentials object for proof creation.

     - Parameters proofRequest: the proof request to build the requested credentials object from.
     - Returns: ``RetrievedCredentials`` object.
    */
    public func getRequestedCredentialsForProofRequest(proofRequest: ProofRequest) async throws -> RetrievedCredentials {
        var retrievedCredentials = RetrievedCredentials()
        let lock = NSLock()

        try await proofRequest.requestedAttributes.concurrentForEach { (referent, requestedAttribute) in
            let credentials = try await self.agent.anoncredsService.getCredentialsForProofRequest(proofRequest, referent: referent)

            let attributes = try await credentials.concurrentMap { credentialInfo -> RequestedAttribute in
                let (revoked, deltaTimestamp) = try await self.getRevocationStatusForRequestedItem(
                    proofRequest: proofRequest,
                    nonRevoked: requestedAttribute.nonRevoked,
                    credential: credentialInfo)

                return RequestedAttribute(
                    credentialId: credentialInfo.referent,
                    timestamp: deltaTimestamp,
                    revealed: true,
                    credentialInfo: credentialInfo,
                    revoked: revoked)
            }
            lock.withLock {
                retrievedCredentials.requestedAttributes[referent] = attributes
            }
        }

        try await proofRequest.requestedPredicates.concurrentForEach { (referent, requestedPredicate) in
            let credentials = try await self.agent.anoncredsService.getCredentialsForProofRequest(proofRequest, referent: referent)

            let predicates = try await credentials.concurrentMap { credentialInfo -> RequestedPredicate in
                let (revoked, deltaTimestamp) = try await self.getRevocationStatusForRequestedItem(
                    proofRequest: proofRequest,
                    nonRevoked: requestedPredicate.nonRevoked,
                    credential: credentialInfo)

                return RequestedPredicate(
                    credentialId: credentialInfo.referent,
                    timestamp: deltaTimestamp,
                    credentialInfo: credentialInfo,
                    revoked: revoked)
            }
            lock.withLock {
                retrievedCredentials.requestedPredicates[referent] = predicates
            }
        }

        return retrievedCredentials
    }

    /**
     Takes a RetrievedCredentials object and auto selects credentials in a RequestedCredentials object.

     Use the return value of this method as input to ``createPresentation(proofRecord:requestedCredentials:comment:)`` to
     automatically select credentials for presentation.

     - Parameters retrievedCredentials: the retrieved credentials to auto select from.
     - Returns: a ``RequestedCredentials`` object.
    */
    public func autoSelectCredentialsForProofRequest(retrievedCredentials: RetrievedCredentials) async throws -> RequestedCredentials {
        var requestedCredentials = RequestedCredentials()
        try retrievedCredentials.requestedAttributes.keys.forEach { attributeName in
            let attributeArray = retrievedCredentials.requestedAttributes[attributeName]!

            if attributeArray.count == 0 {
                throw AriesFrameworkError.frameworkError("Cannot find credentials for attribute '\(attributeName)'.")
            }
            let nonRevokedAttributes = attributeArray.filter { attr in
                attr.revoked != true
            }
            if nonRevokedAttributes.count == 0 {
                throw AriesFrameworkError.frameworkError("Cannot find non-revoked credentials for attribute '\(attributeName)'.")
            }
            requestedCredentials.requestedAttributes[attributeName] = nonRevokedAttributes[0]
        }

        try retrievedCredentials.requestedPredicates.keys.forEach { predicateName in
            let predicateArray = retrievedCredentials.requestedPredicates[predicateName]!

            if predicateArray.count == 0 {
                throw AriesFrameworkError.frameworkError("Cannot find credentials for predicate '\(predicateName)'.")
            }
            let nonRevokedPredicates = predicateArray.filter { pred in
                pred.revoked != true
            }
            if nonRevokedPredicates.count == 0 {
                throw AriesFrameworkError.frameworkError("Cannot find non-revoked credentials for predicate '\(predicateName)'.")
            }
            requestedCredentials.requestedPredicates[predicateName] = nonRevokedPredicates[0]
        }

        return requestedCredentials
    }

    /**
     Verify an indy proof object.

     - Parameters:
        - proofRequest: the proof request to use for proof verification.
        - proof: the proof to verify.
     - Returns: true if the proof is valid, false otherwise.
    */
    public func verifyProof(proofRequest: String, proof: String) async throws -> Bool {
        let partialProof = try JSONDecoder().decode(PartialProof.self, from: proof.data(using: .utf8)!)
        async let schemas = getSchemas(schemaIds: Set(partialProof.identifiers.map { $0.schemaId }))
        async let credentialDefinitions = getCredentialDefinitions(credentialDefinitionIds: Set(partialProof.identifiers.map { $0.credentialDefinitionId }))
        async let revocationRegistryDefinitions = getRevocationRegistryDefinitions(revocationRegistryIds: Set(partialProof.identifiers.compactMap { $0.revocationRegistryId }))
        let revocationStatusLists = try await agent.revocationService.getRevocationStatusLists(proof: partialProof, revocationRegistryDefinitions: revocationRegistryDefinitions)

        do {
            let isVerified = try await Verifier().verifyPresentation(
                presentation: Presentation(json: proof),
                presReq: PresentationRequest(json: proofRequest),
                schemas: schemas,
                credDefs: credentialDefinitions,
                revRegDefs: revocationRegistryDefinitions,
                revStatusLists: revocationStatusLists,
                nonrevokeIntervalOverride: nil)
            return isVerified
        } catch {
            logger.error("Error verifying proof: \(error)")
            return false
        }
    }

    func getRevocationStatusForRequestedItem(
        proofRequest: ProofRequest,
        nonRevoked: RevocationInterval?,
        credential: IndyCredentialInfo) async throws -> (revoked: Bool?, deltaTimestamp: Int?) {

        guard let requestNonRevoked = nonRevoked ?? proofRequest.nonRevoked,
              let credentialRevocationId = credential.credentialRevocationId,
              let revocationRegistryId = credential.revocationRegistryId else {
            return (nil, nil)
        }

        if agent.agentConfig.ignoreRevocationCheck {
            return (false, requestNonRevoked.to)
        }

        return try await agent.revocationService.getRevocationStatus(
            credentialRevocationId: credentialRevocationId,
            revocationRegistryId: revocationRegistryId,
            revocationInterval: requestNonRevoked)
    }

    func createProof(proofRequest: String, requestedCredentials: RequestedCredentials) async throws -> Data {
        var anoncredsCreds = [RequestedCredential]()
        let credentialIds = requestedCredentials.getCredentialIdentifiers()
        var schemaIds = Set<String>()
        var credentialDefinitionIds = Set<String>()

        try await credentialIds.concurrentForEach { [self] (credId) in
            let credentialRecord = try await agent.credentialRepository.getByCredentialId(credId)
            let credential = try Credential(json: credentialRecord.credential)
            schemaIds.insert(credential.schemaId())
            credentialDefinitionIds.insert(credential.credDefId())

            var requestedAttributes = [String: Bool]()
            var requestedPredicates = [String]()
            var timestamp: UInt64?
            requestedCredentials.requestedAttributes.forEach { (referent, attr) in
                if attr.credentialId == credId {
                    requestedAttributes[referent] = attr.revealed
                    if attr.timestamp != nil {
                        timestamp = max(UInt64(attr.timestamp!), timestamp ?? 0)
                    }
                }
            }
            requestedCredentials.requestedPredicates.forEach { (referent, pred) in
                if pred.credentialId == credId {
                    requestedPredicates.append(referent)
                    if pred.timestamp != nil {
                        timestamp = max(UInt64(pred.timestamp!), timestamp ?? 0)
                    }
                }
            }
            var revocationState: CredentialRevocationState?
            if timestamp != nil {
                revocationState = try await revocationService.createRevocationState(credential: credential, timestamp: Int(timestamp!))
            }
            let requestedCredential = RequestedCredential(
                cred: credential,
                timestamp: timestamp,
                revState: revocationState,
                requestedAttributes: requestedAttributes,
                requestedPredicates: requestedPredicates)
            anoncredsCreds.append(requestedCredential)
        }

        let schemas = try await getSchemas(schemaIds: schemaIds)
        let credentialDefinitions = try await getCredentialDefinitions(credentialDefinitionIds: credentialDefinitionIds)
        let linkSecret = try await agent.anoncredsService.getLinkSecret(id: agent.wallet.linkSecretId!)
        do {
            let presentation = try Prover().createPresentation(
                presReq: PresentationRequest(json: proofRequest),
                requestedCredentials: anoncredsCreds,
                selfAttestedAttributes: [:],
                linkSecret: linkSecret,
                schemas: schemas,
                credDefs: credentialDefinitions)

            return presentation.toJson().data(using: .utf8)!
        } catch {
            throw AriesFrameworkError.frameworkError("Cannot create a proof using the provided credentials. \(error)")
        }
    }

    func getSchemas(schemaIds: Set<String>) async throws -> [String: Schema] {
        var schemas = [String: Schema]()
        let lock = NSLock()

        try await schemaIds.concurrentForEach { [self] schemaId in
            let (schema, _) = try await agent.ledgerService.getSchema(schemaId: schemaId)
            try lock.withLock {
                schemas[schemaId] = try Schema(json: schema)
            }
        }

        return schemas
    }

    func getCredentialDefinitions(credentialDefinitionIds: Set<String>) async throws -> [String: CredentialDefinition] {
        var credentialDefinitions = [String: CredentialDefinition]()
        let lock = NSLock()

        try await credentialDefinitionIds.concurrentForEach { [self] credentialDefinitionId in
            let credentialDefinition = try await agent.ledgerService.getCredentialDefinition(id: credentialDefinitionId)
            try lock.withLock {
                credentialDefinitions[credentialDefinitionId] = try CredentialDefinition(json: credentialDefinition)
            }
        }

        return credentialDefinitions
    }

    func getRevocationRegistryDefinitions(revocationRegistryIds: Set<String>) async throws -> [String: RevocationRegistryDefinition] {
        var revocationRegistryDefinitions = [String: RevocationRegistryDefinition]()
        let lock = NSLock()

        try await revocationRegistryIds.concurrentForEach { [self] revocationRegistryId in
            let revocationRegistryDefinition = try await agent.ledgerService.getRevocationRegistryDefinition(id: revocationRegistryId)
            try lock.withLock {
                revocationRegistryDefinitions[revocationRegistryId] = try RevocationRegistryDefinition(json: revocationRegistryDefinition)
            }
        }

        return revocationRegistryDefinitions
    }

    func updateState(proofRecord: inout ProofExchangeRecord, newState: ProofState) async throws {
        proofRecord.state = newState
        try await agent.proofRepository.update(proofRecord)
        agent.agentDelegate?.onProofStateChanged(proofRecord: proofRecord)
    }
}
