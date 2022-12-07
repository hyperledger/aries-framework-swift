
import Foundation
import os

public class CredentialsCommand {
    let agent: Agent
    let logger = Logger(subsystem: "AriesFramework", category: "CredentialsCommand")

    init(agent: Agent, dispatcher: Dispatcher) {
        self.agent = agent
        registerHandlers(dispatcher: dispatcher)
    }

    func registerHandlers(dispatcher: Dispatcher) {
        dispatcher.registerHandler(handler: CredentialAckHandler(agent: agent))
        dispatcher.registerHandler(handler: RequestCredentialHandler(agent: agent))
        dispatcher.registerHandler(handler: IssueCredentialHandler(agent: agent))
        dispatcher.registerHandler(handler: OfferCredentialHandler(agent: agent))
    }

    /**
     Initiate a new credential exchange as holder by sending a credential proposal message
     to the connection with the specified credential options.

     - Parameter options: options for the proposal.
     - Returns: credential record associated with the sent proposal message.
    */
    public func proposeCredential(options: CreateProposalOptions) async throws -> CredentialExchangeRecord {
        let (message, credentialRecord) = try await agent.credentialService.createProposal(options: options)
        try await agent.messageSender.send(message: OutboundMessage(payload: message, connection: options.connection))

        return credentialRecord
    }

    /**
     Initiate a new credential exchange as issuer by sending a credential offer message
     to the connection with the specified connection id.

     - Parameter options: options for the offer.
     - Returns: credential record associated with the sent credential offer message.
    */
    public func offerCredential(options: CreateOfferOptions) async throws -> CredentialExchangeRecord {
        let (message, credentialRecord) = try await agent.credentialService.createOffer(options: options)
        guard let connection = options.connection else {
            throw AriesFrameworkError.frameworkError("Connection is required for sending credential offer")
        }
        try await agent.messageSender.send(message: OutboundMessage(payload: message, connection: connection))

        return credentialRecord
    }

    /**
     Accept a credential offer as holder (by sending a credential request message) to the connection
     associated with the credential record.

     - Parameter options: options to accept the offer.
     - Returns: credential record associated with the sent credential request message.
    */
    public func acceptOffer(options: AcceptOfferOptions) async throws -> CredentialExchangeRecord {
        let message = try await agent.credentialService.createRequest(options: options)
        let credentialRecord = try await agent.credentialRepository.getById(options.credentialRecordId)
        let connection = try await agent.connectionRepository.getById(credentialRecord.connectionId)
        try await agent.messageSender.send(message: OutboundMessage(payload: message, connection: connection))

        return credentialRecord
    }

    /**
     Declines an offer as holder

     - Parameter credentialRecordId: the id of the credential to be declined.
     - Returns: credential record that was declined.
    */
    public func declineOffer(credentialRecordId: String) async throws -> CredentialExchangeRecord {
        var credentialRecord = try await agent.credentialRepository.getById(credentialRecordId)
        try credentialRecord.assertState(CredentialState.OfferReceived)
        try await agent.credentialService.updateState(credentialRecord: &credentialRecord, newState: .Declined)

        return credentialRecord
    }

    /**
     Accept a credential request as issuer (by sending a credential message) to the connection
     associated with the credential record.

     - Parameter options: options to accept the request.
     - Returns: credential record associated with the sent credential message.
    */
    public func acceptRequest(options: AcceptRequestOptions) async throws -> CredentialExchangeRecord {
        let message = try await agent.credentialService.createCredential(options: options)
        let credentialRecord = try await agent.credentialRepository.getById(options.credentialRecordId)
        let connection = try await agent.connectionRepository.getById(credentialRecord.connectionId)
        try await agent.messageSender.send(message: OutboundMessage(payload: message, connection: connection))

        return credentialRecord
    }

    /**
     Accept a credential as holder (by sending a credential acknowledgement message) to the connection
     associated with the credential record.

     - Parameter options: options to accept the credential.
     - Returns: credential record associated with the sent credential acknowledgement message.
    */
    public func acceptCredential(options: AcceptCredentialOptions) async throws -> CredentialExchangeRecord {
        let message = try await agent.credentialService.createAck(options: options)
        let credentialRecord = try await agent.credentialRepository.getById(options.credentialRecordId)
        let connection = try await agent.connectionRepository.getById(credentialRecord.connectionId)
        try await agent.messageSender.send(message: OutboundMessage(payload: message, connection: connection))

        return credentialRecord
    }

    /**
     Find a ``OfferCredentialMessage`` by credential record id.

     - Parameter credentialRecordId: the id of the credential record.
     - Returns: the offer message associated with the credential record.
    */
    public func findOfferMessage(credentialRecordId: String) async throws -> OfferCredentialMessage? {
        guard let messageJson = try await agent.didCommMessageRepository.findAgentMessage(
            associatedRecordId: credentialRecordId,
            messageType: OfferCredentialMessage.type) else {
                return nil
            }
        let message = try JSONDecoder().decode(OfferCredentialMessage.self, from: Data(messageJson.utf8))
        return message
    }

    /**
     Find a ``RequestCredentialMessage`` by credential record id.

     - Parameter credentialRecordId: the id of the credential record.
     - Returns: the request message associated with the credential record.
    */
    public func findRequestMessage(credentialRecordId: String) async throws -> RequestCredentialMessage? {
        guard let messageJson = try await agent.didCommMessageRepository.findAgentMessage(
            associatedRecordId: credentialRecordId,
            messageType: RequestCredentialMessage.type) else {
                return nil
            }
        let message = try JSONDecoder().decode(RequestCredentialMessage.self, from: Data(messageJson.utf8))
        return message
    }

    /**
     Find a ``IssueCredentialMessage`` by credential record id.

     - Parameter credentialRecordId: the id of the credential record.
     - Returns: the credential message associated with the credential record.
    */
    public func findCredentialMessage(credentialRecordId: String) async throws -> IssueCredentialMessage? {
        guard let messageJson = try await agent.didCommMessageRepository.findAgentMessage(
            associatedRecordId: credentialRecordId,
            messageType: IssueCredentialMessage.type) else {
                return nil
            }
        let message = try JSONDecoder().decode(IssueCredentialMessage.self, from: Data(messageJson.utf8))
        return message
    }
}
