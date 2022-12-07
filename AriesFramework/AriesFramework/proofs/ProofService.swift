
import Foundation
import Indy
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
    public static func generateProofRequestNonce() async throws -> String {
        return try await IndyAnoncreds.generateNonce()!
    }

    /**
     Create a ``RetrievedCredentials`` object. Given input proof request,
     use credentials in the wallet to build indy requested credentials object for proof creation.

     - Parameters proofRequest: the proof request to build the requested credentials object from.
     - Returns: ``RetrievedCredentials`` object.
    */
    public func getRequestedCredentialsForProofRequest(proofRequest: ProofRequest) async throws -> RetrievedCredentials {
        var retrievedCredentials = RetrievedCredentials()
        let credentialsForProof = try await getCredentialsForProofRequest(proofRequest)

        try await proofRequest.requestedAttributes.concurrentForEach { (referent, requestedAttribute) in
            guard let credentials = credentialsForProof.attrs[referent] else { return }

            try await retrievedCredentials.requestedAttributes[referent] = credentials.concurrentMap { credential -> RequestedAttribute in
                let (revoked, deltaTimestamp) = try await self.getRevocationStatusForRequestedItem(
                    proofRequest: proofRequest,
                    nonRevoked: requestedAttribute.nonRevoked,
                    credential: credential.credentialInfo)

                return RequestedAttribute(
                    credentialId: credential.credentialInfo.referent,
                    timestamp: deltaTimestamp,
                    revealed: true,
                    credentialInfo: credential.credentialInfo,
                    revoked: revoked)
            }
        }

        try await proofRequest.requestedPredicates.concurrentForEach { (referent, requestedPredicate) in
            guard let credentials = credentialsForProof.predicates[referent] else { return }

            try await retrievedCredentials.requestedPredicates[referent] = credentials.concurrentMap { credential -> RequestedPredicate in
                let (revoked, deltaTimestamp) = try await self.getRevocationStatusForRequestedItem(
                    proofRequest: proofRequest,
                    nonRevoked: requestedPredicate.nonRevoked,
                    credential: credential.credentialInfo)

                return RequestedPredicate(
                    credentialId: credential.credentialInfo.referent,
                    timestamp: deltaTimestamp,
                    credentialInfo: credential.credentialInfo,
                    revoked: revoked)
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
            } else {
                requestedCredentials.requestedAttributes[attributeName] = attributeArray[0]
            }
        }

        try retrievedCredentials.requestedPredicates.keys.forEach { predicateName in
            let predicateArray = retrievedCredentials.requestedPredicates[predicateName]!

            if predicateArray.count == 0 {
                throw AriesFrameworkError.frameworkError("Cannot find credentials for predicate '\(predicateName)'.")
            } else {
                requestedCredentials.requestedPredicates[predicateName] = predicateArray[0]
            }
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
        async let revocationRegistries = agent.revocationService.getRevocationRegistries(proof: partialProof)

        return try await IndyAnoncreds.verifierVerifyProofRequest(proofRequest,
            proofJSON: proof,
            schemasJSON: schemas,
            credentialDefsJSON: credentialDefinitions,
            revocRegDefsJSON: revocationRegistryDefinitions,
            revocRegsJSON: revocationRegistries)
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

        return try await agent.revocationService.getRevocationStatus(
            credentialRevocationId: credentialRevocationId,
            revocationRegistryId: revocationRegistryId,
            revocationInterval: requestNonRevoked)
    }

    func getCredentialsForProofRequest(_ proofRequest: ProofRequest) async throws -> CredentialsForProof {
        let credentials = try await IndyAnoncreds.proverGetCredentials(forProofReq: proofRequest.toString(), walletHandle: agent.wallet.handle!)
        return try JSONDecoder().decode(CredentialsForProof.self, from: credentials!.data(using: .utf8)!)
    }

    func createProof(proofRequest: String, requestedCredentials: RequestedCredentials) async throws -> Data {
        var credentialObjects = [IndyCredentialInfo]()
        var requestedAttributes = [String: RequestedAttribute]()
        var requestedPredicates = [String: RequestedPredicate]()
        try await requestedCredentials.requestedAttributes.concurrentForEach { (k, v) in
            let credentialInfo = try await self.getCredential(credentialId: v.credentialId)
            var attribute = v
            attribute.setCredentialInfo(credentialInfo)
            requestedAttributes[k] = attribute
            credentialObjects.append(credentialInfo)
        }
        try await requestedCredentials.requestedPredicates.concurrentForEach { (k, v) in
            let credentialInfo = try await self.getCredential(credentialId: v.credentialId)
            var attribute = v
            attribute.setCredentialInfo(credentialInfo)
            requestedPredicates[k] = attribute
            credentialObjects.append(credentialInfo)
        }
        var requestedCredentials = requestedCredentials
        requestedCredentials.requestedAttributes = requestedAttributes
        requestedCredentials.requestedPredicates = requestedPredicates
        let requestedCredentialsClone = requestedCredentials

        let credentialObjectsClone = credentialObjects
        async let schemas = getSchemas(schemaIds: Set(credentialObjectsClone.map { $0.schemaId }))
        async let credentialDefinitions = getCredentialDefinitions(credentialDefinitionIds: Set(credentialObjectsClone.map { $0.credentialDefinitionId }))
        async let revocationStates = revocationService.createRevocationState(proofRequestJson: proofRequest, requestedCredentials: requestedCredentialsClone)

        let indyProof = try await IndyAnoncreds.proverCreateProof(
            forRequest: proofRequest,
            requestedCredentialsJSON: requestedCredentials.toString(),
            masterSecretID: agent.wallet.masterSecretId,
            schemasJSON: schemas,
            credentialDefsJSON: credentialDefinitions,
            revocStatesJSON: revocationStates,
            walletHandle: agent.wallet.handle!)

        let revocationStatesClone = try await revocationStates
        logger.debug("revocationStates: \(revocationStatesClone)")

        return indyProof!.data(using: .utf8)!
    }

    func getCredential(credentialId: String) async throws -> IndyCredentialInfo {
        let credential = try await IndyAnoncreds.proverGetCredential(withId: credentialId, walletHandle: agent.wallet.handle!)!
        let credentialInfo = try JSONDecoder().decode(IndyCredentialInfo.self, from: credential.data(using: .utf8)!)
        return credentialInfo
    }

    func getSchemas(schemaIds: Set<String>) async throws -> String {
        var schemas = [String: Any]()

        try await schemaIds.concurrentForEach { [self] schemaId in
            let schema = try await agent.ledgerService.getSchema(schemaId: schemaId)
            let schemaObj = try JSONSerialization.jsonObject(with: schema.data(using: .utf8)!, options: [])
            schemas[schemaId] = schemaObj
        }

        let schemasJson = try JSONSerialization.data(withJSONObject: schemas, options: [])
        return String(data: schemasJson, encoding: .utf8)!
    }

    func getCredentialDefinitions(credentialDefinitionIds: Set<String>) async throws -> String {
        var credentialDefinitions = [String: Any]()

        try await credentialDefinitionIds.concurrentForEach { [self] credentialDefinitionId in
            let credentialDefinition = try await agent.ledgerService.getCredentialDefinition(id: credentialDefinitionId)
            let credentialDefinitionObj = try JSONSerialization.jsonObject(with: credentialDefinition.data(using: .utf8)!, options: [])
            credentialDefinitions[credentialDefinitionId] = credentialDefinitionObj
        }

        let credentialDefinitionsJson = try JSONSerialization.data(withJSONObject: credentialDefinitions, options: [])
        return String(data: credentialDefinitionsJson, encoding: .utf8)!
    }

    func getRevocationRegistryDefinitions(revocationRegistryIds: Set<String>) async throws -> String {
        var revocationRegistryDefinitions = [String: Any]()

        try await revocationRegistryIds.concurrentForEach { [self] revocationRegistryId in
            let revocationRegistryDefinition = try await agent.ledgerService.getRevocationRegistryDefinition(id: revocationRegistryId)
            let revocationRegistryDefinitionObj = try JSONSerialization.jsonObject(with: revocationRegistryDefinition.data(using: .utf8)!, options: [])
            revocationRegistryDefinitions[revocationRegistryId] = revocationRegistryDefinitionObj
        }

        let revocationRegistryDefinitionsJson = try JSONSerialization.data(withJSONObject: revocationRegistryDefinitions, options: [])
        return String(data: revocationRegistryDefinitionsJson, encoding: .utf8)!
    }

    func updateState(proofRecord: inout ProofExchangeRecord, newState: ProofState) async throws {
        proofRecord.state = newState
        try await agent.proofRepository.update(proofRecord)
        agent.agentDelegate?.onProofStateChanged(proofRecord: proofRecord)
    }
}
