
import Foundation
import os

public class DidExchangeService {
    let agent: Agent
    let connectionRepository: ConnectionRepository
    let connectionWaiter = AsyncWaiter()
    let logger = Logger(subsystem: "AriesFramework", category: "DidExchangeService")

    init(agent: Agent) {
        self.agent = agent
        self.connectionRepository = agent.connectionRepository
    }

    /**
     Create a DID exchange request message for the connection with the specified connection id.

     - Parameters:
       - connectionId: the id of the connection for which to create a DID exchange request.
       - label: the label to use for the DID exchange request.
       - autoAcceptConnection: whether to automatically accept the DID exchange response.
     - Returns: outbound message containing DID exchange request.
    */
    public func createRequest(
        connectionId: String,
        label: String? = nil,
        autoAcceptConnection: Bool? = nil) async throws -> OutboundMessage {

        var connectionRecord = try await self.connectionRepository.getById(connectionId)
        assert(connectionRecord.state == ConnectionState.Invited)
        assert(connectionRecord.role == ConnectionRole.Invitee)

        // TODO: get peer did from connectionRecord.did
        let peerDid = "did:peer:0z6MkpTHR8VNsBxYAAWHut2Geadd9jSwuBV8xRoAnwWsdvktH"
        let message = DidExchangeRequestMessage(label: label ?? agent.agentConfig.label, did: peerDid)

        if autoAcceptConnection != nil {
            connectionRecord.autoAcceptConnection = autoAcceptConnection
        }
        connectionRecord.threadId = message.id
        try await updateState(connectionRecord: &connectionRecord, newState: ConnectionState.Requested)

        return OutboundMessage(payload: message, connection: connectionRecord)
    }

    /**
     Process a received DID exchange request message. This will not accept the DID exchange request
     or send a DID exchange response message. It will only update the existing connection record
     with all the new information from the DID exchange request message. Use ``createResponse(connectionId:)``
     after calling this function to create a DID exchange response.

     - Parameter messageContext: the message context containing the DID exchange request message.
     - Returns: updated connection record.
    */
    public func processRequest(messageContext: InboundMessageContext) async throws -> ConnectionRecord {
        let decoder = JSONDecoder()
        let message = try decoder.decode(DidExchangeRequestMessage.self, from: Data(messageContext.plaintextMessage.utf8))

        guard let recipientKey = messageContext.recipientVerkey, let senderKey = messageContext.senderVerkey else {
            throw AriesFrameworkError.frameworkError("Unable to process connection request without senderVerkey or recipientVerkey")
        }

        var outOfBandRecord: OutOfBandRecord?
        let outOfBandRecords = await agent.outOfBandService.findAllByInvitationKey(recipientKey)
        if outOfBandRecords.isEmpty {
            throw AriesFrameworkError.frameworkError("No out-of-band record or connection record found for invitation key: \(recipientKey)")
        } else {
            outOfBandRecord = outOfBandRecords[0]
        }

        // TODO: get didDoc from message.did
        let didDoc = ""

        var connectionRecord = try await agent.connectionService.createConnection(
            role: .Inviter,
            state: .Invited,
            invitation: nil,
            outOfBandInvitation: outOfBandRecord!.outOfBandInvitation,
            alias: nil,
            routing: agent.mediationRecipient.getRouting(),
            theirLabel: message.label,
            autoAcceptConnection: outOfBandRecord!.autoAcceptConnection,
            multiUseInvitation: true,
            imageUrl: message.imageUrl,
            threadId: message.threadId)

        try await self.connectionRepository.save(connectionRecord)

        connectionRecord.theirDidDoc = didDoc
        connectionRecord.theirLabel = message.label
        connectionRecord.threadId = message.id
        connectionRecord.theirDid = didDoc.id
        connectionRecord.imageUrl = message.imageUrl

        if connectionRecord.theirKey() == nil {
            throw AriesFrameworkError.frameworkError("Connection with id \(connectionRecord!.id) has no recipient keys.")
        }

        try await updateState(connectionRecord: &connectionRecord, newState: .Requested)
        return connectionRecord!
    }

    /**
     Create a DID exchange response message for the connection with the specified connection id.

     - Parameter connectionId: the id of the connection for which to create a DID exchange response.
     - Returns: outbound message containing DID exchange response.
    */
    public func createResponse(connectionId: String) async throws -> OutboundMessage {
        var connectionRecord = try await connectionRepository.getById(connectionId)
        assert(connectionRecord.state == ConnectionState.Requested)
        assert(connectionRecord.role == ConnectionRole.Inviter)
        guard let threadId = connectionRecord.threadId else {
            throw AriesFrameworkError.frameworkError("Connection record with id \(connectionRecord.id) has no thread id.")
        }

        // TODO: get peer did from connectionRecord.did
        let peerDid = "did:peer:0z6MkpTHR8VNsBxYAAWHut2Geadd9jSwuBV8xRoAnwWsdvktH"

        let message = DidExchangeResponseMessage(threadId: threadId, did: peerDid)
        message.thread = ThreadDecorator(threadId: threadId)

        try await updateState(connectionRecord: &connectionRecord, newState: .Responded)

        return OutboundMessage(payload: message, connection: connectionRecord)
    }

    /**
     Process a received DID exchange response message. This will not accept the DID exchange response
     or send a DID exchange complete message. It will only update the existing connection record
     with all the new information from the DID exchange response message. Use ``createComplete(connectionId:)``
     after calling this function to create a DID exchange complete message.

     - Parameter messageContext: the message context containing a DID exchange response message.
     - Returns: updated connection record.
    */
    public func processResponse(messageContext: InboundMessageContext) async throws -> ConnectionRecord {
        let decoder = JSONDecoder()
        let message = try decoder.decode(DidExchangeResponseMessage.self, from: Data(messageContext.plaintextMessage.utf8))

        var connectionRecord: ConnectionRecord!
        do {
            connectionRecord = try await agent.connectionService.getByThreadId(message.threadId)
        } catch {
            throw AriesFrameworkError.frameworkError("Unable to process DID exchange response: connection for threadId: \(message.threadId) not found")
        }
        assert(connectionRecord.state == ConnectionState.Requested)
        assert(connectionRecord.role == ConnectionRole.Invitee)

        if message.thread != connectionRecord.threadId {
            throw AriesFrameworkError.frameworkError("Invalid or missing thread ID")
        }

        // TODO: get didDoc from message.did
        let didDoc = ""

        connectionRecord.theirDid = didDoc.id
        connectionRecord.theirDidDoc = didDoc

        try await updateState(connectionRecord: &connectionRecord, newState: ConnectionState.Responded)
        return connectionRecord
    }

    /**
     Create a DID exchange complete message for the connection with the specified connection id.

     - Parameter connectionId: the id of the connection for which to create a DID exchange complete message.
     - Returns: outbound message containing a DID exchange complete message.
    */
    public func createComplete(connectionId: String) async throws -> OutboundMessage {
        var connectionRecord = try await self.connectionRepository.getById(connectionId)
        assert(connectionRecord.state == ConnectionState.Responded)

        guard let threadId = connectionRecord.threadId else {
            throw AriesFrameworkError.frameworkError("Connection record with id \(connectionRecord.id) has no thread id.")
        }
        guard let parentThreadId = connectionRecord.outOfBandInvitation?.id else {
            throw AriesFrameworkError.frameworkError("Connection record with id \(connectionRecord.id) has no parent thread id.")
        }

        let message = DidExchangeCompleteMessage(threadId: threadId, parentThreadId: parentThreadId)
        try await updateState(connectionRecord: &connectionRecord, newState: ConnectionState.Complete)

        return OutboundMessage(payload: message, connection: connectionRecord)
    }

    func updateState(connectionRecord: inout ConnectionRecord, newState: ConnectionState) async throws {
        connectionRecord.state = newState
        try await self.connectionRepository.update(connectionRecord)
        if newState == ConnectionState.Complete {
            finishConnectionWaiter()
        }
        agent.agentDelegate?.onConnectionStateChanged(connectionRecord: connectionRecord)
    }

    func waitForConnection() async throws -> Bool {
        return try await connectionWaiter.wait()
    }

    private func finishConnectionWaiter() {
        connectionWaiter.finish()
    }
}
