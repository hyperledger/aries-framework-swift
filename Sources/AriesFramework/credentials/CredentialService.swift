
import Foundation
import Anoncreds
import os

public class CredentialService {
    let agent: Agent
    let credentialExchangeRepository: CredentialExchangeRepository
    let ledgerService: LedgerService
    let logger = Logger(subsystem: "AriesFramework", category: "CredentialService")

    init(agent: Agent) {
        self.agent = agent
        self.credentialExchangeRepository = agent.credentialExchangeRepository
        self.ledgerService = agent.ledgerService
    }

    /**
     Create a ``ProposeCredentialMessage`` not bound to an existing credential record.

     - Parameter options: options for the proposal.
     - Returns: proposal message and associated credential record.
    */
    public func createProposal(options: CreateProposalOptions) async throws -> (ProposeCredentialMessage, CredentialExchangeRecord) {
        let credentialRecord = CredentialExchangeRecord(
            connectionId: options.connection.id,
            threadId: CredentialExchangeRecord.generateId(),
            state: .ProposalSent,
            autoAcceptCredential: options.autoAcceptCredential,
            protocolVersion: "v1")

        let message = ProposeCredentialMessage(
            id: credentialRecord.threadId,
            comment: options.comment,
            credentialPreview: options.credentialPreview,
            schemaIssuerDid: options.schemaIssuerDid,
            schemaId: options.schemaId,
            schemaName: options.schemaName,
            schemaVersion: options.schemaVersion,
            credentialDefinitionId: options.credentialDefinitionId,
            issuerDid: options.issuerDid)

        try await agent.didCommMessageRepository.saveAgentMessage(
            role: .Sender,
            agentMessage: message,
            associatedRecordId: credentialRecord.id)

        try await credentialExchangeRepository.save(credentialRecord)
        agent.agentDelegate?.onCredentialStateChanged(credentialRecord: credentialRecord)

        return (message, credentialRecord)
    }

    /**
     Create a ``OfferCredentialMessage`` not bound to an existing credential record.

     - Parameter options: options for the offer.
     - Returns: offer message and associated credential record.
    */
    public func createOffer(options: CreateOfferOptions) async throws -> (OfferCredentialMessage, CredentialExchangeRecord) {
        if options.connection == nil {
            logger.info("Creating credential offer without connection. This should be used for out-of-band request message with handshake.")
        }
        var credentialRecord = CredentialExchangeRecord(
            connectionId: options.connection?.id ?? "connectionless-offer",
            threadId: CredentialExchangeRecord.generateId(),
            state: .OfferSent,
            autoAcceptCredential: options.autoAcceptCredential,
            protocolVersion: "v1")

        let credentialDefinitionRecord = try await agent.credentialDefinitionRepository.getByCredDefId(options.credentialDefinitionId)
        let offer = try Issuer().createCredentialOffer(
            schemaId: credentialDefinitionRecord.schemaId,
            credDefId: credentialDefinitionRecord.credDefId,
            keyProof: try CredentialKeyCorrectnessProof(json: credentialDefinitionRecord.keyCorrectnessProof))
        let attachment = Attachment.fromData(offer.toJson().data(using: .utf8)!, id: OfferCredentialMessage.INDY_CREDENTIAL_OFFER_ATTACHMENT_ID)
        let credentialPreview = CredentialPreview(attributes: options.attributes)

        let message = OfferCredentialMessage(
            id: credentialRecord.threadId,
            comment: options.comment,
            credentialPreview: credentialPreview,
            offerAttachments: [attachment])

        try await agent.didCommMessageRepository.saveAgentMessage(
            role: .Sender,
            agentMessage: message,
            associatedRecordId: credentialRecord.id)

        credentialRecord.credentialAttributes = options.attributes
        try await credentialExchangeRepository.save(credentialRecord)
        agent.agentDelegate?.onCredentialStateChanged(credentialRecord: credentialRecord)

        return (message, credentialRecord)
    }

    /**
     Process a received ``OfferCredentialMessage``. This will not accept the credential offer
     or send a credential request. It will only create a new credential record with
     the information from the credential offer message. Use ``createRequest(options:)``
     after calling this method to create a credential request.

     - Parameter messageContext: message context containing the offer message.
     - Returns: credential record associated with the credential offer message.
    */
    public func processOffer(messageContext: InboundMessageContext) async throws -> CredentialExchangeRecord {
        let offerMessage = try JSONDecoder().decode(OfferCredentialMessage.self, from: Data(messageContext.plaintextMessage.utf8))

        if offerMessage.getOfferAttachmentById(OfferCredentialMessage.INDY_CREDENTIAL_OFFER_ATTACHMENT_ID) == nil {
            throw AriesFrameworkError.frameworkError("Indy attachment with id \(OfferCredentialMessage.INDY_CREDENTIAL_OFFER_ATTACHMENT_ID) not found in offer message")
        }

        let credentialRecord = try await credentialExchangeRepository.findByThreadAndConnectionId(
            threadId: offerMessage.threadId,
            connectionId: messageContext.connection?.id)

        if var credentialRecord = credentialRecord {
            try await agent.didCommMessageRepository.saveOrUpdateAgentMessage(
                role: DidCommMessageRole.Receiver,
                agentMessage: offerMessage,
                associatedRecordId: credentialRecord.id
            )
            try await updateState(credentialRecord: &credentialRecord, newState: .OfferReceived)

            return credentialRecord
        } else {
            let connection = try messageContext.assertReadyConnection()
            let credentialRecord = CredentialExchangeRecord(
                connectionId: connection.id,
                threadId: offerMessage.id,
                state: .OfferReceived,
                protocolVersion: "v1")

            try await agent.didCommMessageRepository.saveAgentMessage(
                role: .Receiver,
                agentMessage: offerMessage,
                associatedRecordId: credentialRecord.id)

            try await credentialExchangeRepository.save(credentialRecord)
            agent.agentDelegate?.onCredentialStateChanged(credentialRecord: credentialRecord)

            return credentialRecord
        }
    }

    /**
     Create a ``RequestCredentialMessage`` as response to a received credential offer.

     - Parameter options: options for the request.
     - Returns: request message.
    */
    public func createRequest(options: AcceptOfferOptions) async throws -> RequestCredentialMessage {
        var credentialRecord = try await credentialExchangeRepository.getById(options.credentialRecordId)
        try credentialRecord.assertProtocolVersion("v1")
        try credentialRecord.assertState(CredentialState.OfferReceived)

        let offerMessageJson = try await agent.didCommMessageRepository.getAgentMessage(
            associatedRecordId: credentialRecord.id,
            messageType: OfferCredentialMessage.type)
        let offerMessage = try JSONDecoder().decode(OfferCredentialMessage.self, from: Data(offerMessageJson.utf8))

        let offerAttachment = offerMessage.getOfferAttachmentById(OfferCredentialMessage.INDY_CREDENTIAL_OFFER_ATTACHMENT_ID)
        if offerAttachment == nil {
            throw AriesFrameworkError.frameworkError("Indy attachment with id \(OfferCredentialMessage.INDY_CREDENTIAL_OFFER_ATTACHMENT_ID) not found in offer message")
        }

        var holderDid: String!
        if options.holderDid != nil {
            holderDid = options.holderDid!
        } else {
            holderDid = try await getHolderDid(credentialRecord: credentialRecord)
        }
        let credentialOfferJson = try offerMessage.getCredentialOffer()
        let credentialOffer = try CredentialOffer(json: credentialOfferJson)
        let credentialDefinition = try await ledgerService.getCredentialDefinition(id: credentialOffer.credDefId())

        let linkSecret = try await agent.anoncredsService.getLinkSecret(id: agent.wallet.linkSecretId!)
        let credReqTuple = try Prover().createCredentialRequest(
            entropy: nil,
            proverDid: holderDid,
            credDef: try CredentialDefinition(json: credentialDefinition),
            linkSecret: linkSecret,
            linkSecretId: agent.wallet.linkSecretId!,
            credOffer: credentialOffer)

        credentialRecord.indyRequestMetadata = credReqTuple.metadata.toJson()
        credentialRecord.credentialDefinitionId = credentialOffer.credDefId()

        let attachment = Attachment.fromData(credReqTuple.request.toJson().data(using: .utf8)!, id: RequestCredentialMessage.INDY_CREDENTIAL_REQUEST_ATTACHMENT_ID)
        let requestMessage = RequestCredentialMessage(
            id: nil,
            comment: options.comment,
            requestAttachments: [attachment])
        requestMessage.thread = ThreadDecorator(threadId: credentialRecord.threadId)

        credentialRecord.credentialAttributes = offerMessage.credentialPreview.attributes
        credentialRecord.autoAcceptCredential = options.autoAcceptCredential ?? credentialRecord.autoAcceptCredential

        try await agent.didCommMessageRepository.saveOrUpdateAgentMessage(
            role: DidCommMessageRole.Sender,
            agentMessage: requestMessage,
            associatedRecordId: credentialRecord.id)
        try await updateState(credentialRecord: &credentialRecord, newState: .RequestSent)

        return requestMessage
    }

    /**
     Process a received ``RequestCredentialMessage``. This will not accept the credential request
     or send a credential. It will only update the existing credential record with
     the information from the credential request message. Use ``createCredential(options:)``
     after calling this method to create a credential.

     - Parameter messageContext: message context containing the request message.
     - Returns: credential record associated with the credential request message.
    */
    public func processRequest(messageContext: InboundMessageContext) async throws -> CredentialExchangeRecord {
        let requestMessage = try JSONDecoder().decode(RequestCredentialMessage.self, from: Data(messageContext.plaintextMessage.utf8))

        if requestMessage.getRequestAttachmentById(RequestCredentialMessage.INDY_CREDENTIAL_REQUEST_ATTACHMENT_ID) == nil {
            throw AriesFrameworkError.frameworkError("Indy attachment with id \(RequestCredentialMessage.INDY_CREDENTIAL_REQUEST_ATTACHMENT_ID) not found in request message")
        }

        var credentialRecord = try await credentialExchangeRepository.getByThreadAndConnectionId(
            threadId: requestMessage.threadId,
            connectionId: nil)

        // The credential offer may have been a connectionless-offer.
        let connection = try messageContext.assertReadyConnection()
        credentialRecord.connectionId = connection.id

        try await agent.didCommMessageRepository.saveAgentMessage(
            role: DidCommMessageRole.Receiver,
            agentMessage: requestMessage,
            associatedRecordId: credentialRecord.id
        )
        try await updateState(credentialRecord: &credentialRecord, newState: .RequestReceived)

        return credentialRecord
    }

    /**
     Create a ``IssueCredentialMessage`` as response to a received credential request.

     - Parameter options: options for the credential issueance.
     - Returns: credential message.
    */
    public func createCredential(options: AcceptRequestOptions) async throws -> IssueCredentialMessage {
        var credentialRecord = try await credentialExchangeRepository.getById(options.credentialRecordId)
        try credentialRecord.assertProtocolVersion("v1")
        try credentialRecord.assertState(CredentialState.RequestReceived)

        let offerMessageJson = try await agent.didCommMessageRepository.getAgentMessage(
            associatedRecordId: credentialRecord.id,
            messageType: OfferCredentialMessage.type)
        let offerMessage = try JSONDecoder().decode(OfferCredentialMessage.self, from: Data(offerMessageJson.utf8))
        let requestMessageJson = try await agent.didCommMessageRepository.getAgentMessage(
            associatedRecordId: credentialRecord.id,
            messageType: RequestCredentialMessage.type)
        let requestMessage = try JSONDecoder().decode(RequestCredentialMessage.self, from: Data(requestMessageJson.utf8))

        let offerAttachment = offerMessage.getOfferAttachmentById(OfferCredentialMessage.INDY_CREDENTIAL_OFFER_ATTACHMENT_ID)
        let requestAttachment = requestMessage.getRequestAttachmentById(RequestCredentialMessage.INDY_CREDENTIAL_REQUEST_ATTACHMENT_ID)
        if offerAttachment == nil || requestAttachment == nil {
            throw AriesFrameworkError.frameworkError("Missing data payload in offer or request attachment in credential Record \(credentialRecord.id)")
        }

        let offer = try CredentialOffer(json: offerAttachment!.getDataAsString())
        let request = try CredentialRequest(json: requestAttachment!.getDataAsString())
        let credDefId = offer.credDefId()
        let credentialDefinitionRecord = try await agent.credentialDefinitionRepository.getByCredDefId(credDefId)

        var revocationConfig: CredentialRevocationConfig?
        if let revocationRecord = try await agent.revocationRegistryRepository.findByCredDefId(credDefId) {
            let registryIndex = try await agent.revocationRegistryRepository.incrementRegistryIndex(credDefId: credDefId)
            revocationConfig = CredentialRevocationConfig(
                regDef: try RevocationRegistryDefinition(json: revocationRecord.revocRegDef),
                regDefPrivate: try RevocationRegistryDefinitionPrivate(json: revocationRecord.revocRegPrivate),
                statusList: try Anoncreds.RevocationStatusList(json: revocationRecord.revocStatusList),
                registryIndex: UInt32(registryIndex))
        }

        let credential = try Issuer().createCredential(
            credDef: try CredentialDefinition(json: credentialDefinitionRecord.credDef),
            credDefPrivate: try CredentialDefinitionPrivate(json: credentialDefinitionRecord.credDefPriv),
            credOffer: offer,
            credRequest: request,
            attrRawValues: credentialRecord.getCredentialInfo()!.claims,
            attrEncValues: nil,
            revocationConfig: revocationConfig)

        let attachment = Attachment.fromData(credential.toJson().data(using: .utf8)!, id: IssueCredentialMessage.INDY_CREDENTIAL_ATTACHMENT_ID)
        let issueMessage = IssueCredentialMessage( comment: options.comment, credentialAttachments: [attachment])
        issueMessage.thread = ThreadDecorator(threadId: credentialRecord.threadId)

        try await agent.didCommMessageRepository.saveOrUpdateAgentMessage(
            role: DidCommMessageRole.Sender,
            agentMessage: issueMessage,
            associatedRecordId: credentialRecord.id)

        credentialRecord.autoAcceptCredential = options.autoAcceptCredential ?? credentialRecord.autoAcceptCredential
        try await updateState(credentialRecord: &credentialRecord, newState: .CredentialIssued)

        return issueMessage
    }

    /**
     Process a received ``IssueCredentialMessage``. This will store the credential, but not accept it yet.
     Use ``createAck(options:)`` after calling this method to accept the credential and create an ack message.

     - Parameter messageContext: message context containing the credential message.
     - Returns: credential record associated with the credential message.
    */
    public func processCredential(messageContext: InboundMessageContext) async throws -> CredentialExchangeRecord {
        let issueMessage = try JSONDecoder().decode(IssueCredentialMessage.self, from: Data(messageContext.plaintextMessage.utf8))

        guard let issueAttachment = issueMessage.getCredentialAttachmentById(IssueCredentialMessage.INDY_CREDENTIAL_ATTACHMENT_ID) else {
            throw AriesFrameworkError.frameworkError("Indy attachment with id \(IssueCredentialMessage.INDY_CREDENTIAL_ATTACHMENT_ID) not found in issue message")
        }

        var credentialRecord = try await credentialExchangeRepository.getByThreadAndConnectionId(
            threadId: issueMessage.threadId,
            connectionId: messageContext.connection?.id)

        let credential = try Credential(json: issueAttachment.getDataAsString())
        let (schemaJson, _) = try await ledgerService.getSchema(schemaId: credential.schemaId())
        let schema = try Schema(json: schemaJson)
        let credentialDefinition = try CredentialDefinition(json: try await ledgerService.getCredentialDefinition(id: credential.credDefId()))
        let revocationRegistryJson = credential.revRegId() != nil ? try await ledgerService.getRevocationRegistryDefinition(id: credential.revRegId()!) : nil
        let revocationRegistry = revocationRegistryJson != nil ? try RevocationRegistryDefinition(json: revocationRegistryJson!) : nil
        if revocationRegistry != nil {
            Task {
                _ = try agent.revocationService.downloadTails(revocationRegistryDefinition: revocationRegistry!)
            }
        }

        let linkSecret = try await agent.anoncredsService.getLinkSecret(id: agent.wallet.linkSecretId!)
        let processedCredential = try Prover().processCredential(
            cred: credential,
            credReqMetadata: CredentialRequestMetadata(json: credentialRecord.indyRequestMetadata!),
            linkSecret: linkSecret,
            credDef: credentialDefinition,
            revRegDef: revocationRegistry)

        let credentialId = UUID().uuidString
        try await agent.credentialRepository.save(
            CredentialRecord(
                credentialId: credentialId,
                credentialRevocationId: processedCredential.revRegIndex().map { String($0) },
                revocationRegistryId: processedCredential.revRegId(),
                linkSecretId: agent.wallet.linkSecretId!,
                credential: processedCredential,
                schemaId: processedCredential.schemaId(),
                schemaName: schema.name(),
                schemaVersion: schema.version(),
                schemaIssuerId: schema.issuerId(),
                issuerId: credentialDefinition.issuerId(),
                credentialDefinitionId: processedCredential.credDefId()))
        try await agent.didCommMessageRepository.saveAgentMessage(
            role: DidCommMessageRole.Receiver,
            agentMessage: issueMessage,
            associatedRecordId: credentialRecord.id)

        credentialRecord.credentials.append(CredentialRecordBinding(credentialRecordType: "indy", credentialRecordId: credentialId))
        try await updateState(credentialRecord: &credentialRecord, newState: .CredentialReceived)

        return credentialRecord
    }

    /**
     Create an ``CredentialAckMessage`` as response to a received credential.

     - Parameter options: options for the acknowledgement message.
     - Returns: credential acknowledgement message.
    */
    public func createAck(options: AcceptCredentialOptions) async throws -> CredentialAckMessage {
        var credentialRecord = try await credentialExchangeRepository.getById(options.credentialRecordId)
        try credentialRecord.assertProtocolVersion("v1")
        try credentialRecord.assertState(CredentialState.CredentialReceived)

        let ackMessage = CredentialAckMessage(
            threadId: credentialRecord.threadId,
            status: .OK)

        try await updateState(credentialRecord: &credentialRecord, newState: .Done)

        return ackMessage
    }

    /**
     Process a received ``CredentialAckMessage``.

     - Parameter messageContext: message context containing the credential acknowledgement message.
     - Returns: credential record associated with the credential acknowledgement message.
    */
    public func processAck(messageContext: InboundMessageContext) async throws -> CredentialExchangeRecord {
        let ackMessage = try JSONDecoder().decode(CredentialAckMessage.self, from: Data(messageContext.plaintextMessage.utf8))

        var credentialRecord = try await credentialExchangeRepository.getByThreadAndConnectionId(
            threadId: ackMessage.threadId,
            connectionId: messageContext.connection?.id)

        try await updateState(credentialRecord: &credentialRecord, newState: .Done)

        return credentialRecord
    }

    /**
     Create a ``ProblemReportMessage`` as response to a received credential offer.

     - Parameter credentialRecordId: credential record that was declined
     - Returns: credential-problem-report message.
    */
    public func createOfferDeclinedProblemReport(credentialRecordId: String) async throws -> CredentialProblemReportMessage {
        var credentialRecord = try await credentialExchangeRepository.getById(credentialRecordId)
        try credentialRecord.assertProtocolVersion("v1")
        try credentialRecord.assertState(CredentialState.OfferReceived)

        let message = CredentialProblemReportMessage(threadId: credentialRecord.threadId)
        try await updateState(credentialRecord: &credentialRecord, newState: .Declined)

        return message
    }

    func getHolderDid(credentialRecord: CredentialExchangeRecord) async throws -> String {
        let connection = try await agent.connectionRepository.getById(credentialRecord.connectionId)
        return connection.did
    }

    func updateState(credentialRecord: inout CredentialExchangeRecord, newState: CredentialState) async throws {
        credentialRecord.state = newState
        try await credentialExchangeRepository.update(credentialRecord)
        agent.agentDelegate?.onCredentialStateChanged(credentialRecord: credentialRecord)
    }
}
