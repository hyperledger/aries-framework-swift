
import Foundation
import os

public struct Routing {
    let endpoints: [String]
    let verkey: String
    let did: String
    let routingKeys: [String]
    let mediatorId: String?
}

public class ConnectionService {
    let agent: Agent
    let connectionRepository: ConnectionRepository
    let connectionWaiter = AsyncWaiter()
    let logger = Logger(subsystem: "AriesFramework", category: "ConnectionService")

    init(agent: Agent) {
        self.agent = agent
        self.connectionRepository = agent.connectionRepository
    }

    /**
     Create a new connection record containing a connection invitation message.

     - Parameters:
       - routing: routing information for the connection.
       - autoAcceptConnection: whether to auto accept the connection request.
       - alias: alias for the connection.
       - multiUseInvitation: allow the creation of a reusable invitation.
       - label: label for the connection.
       - imageUrl: image url for the connection.
     - Returns: outbound message containing connection invitation.
    */
    public func createInvitation(
        routing: Routing,
        autoAcceptConnection: Bool? = nil,
        alias: String? = nil,
        multiUseInvitation: Bool? = nil,
        label: String? = nil,
        imageUrl: String? = nil) async throws -> OutboundMessage {

        var connectionRecord = try await self.createConnection(
            role: ConnectionRole.Inviter,
            state: ConnectionState.Invited,
            invitation: nil,
            alias: alias,
            routing: routing,
            theirLabel: nil,
            autoAcceptConnection: autoAcceptConnection,
            multiUseInvitation: multiUseInvitation ?? false,
            tags: nil,
            imageUrl: nil,
            threadId: nil)

        let service = connectionRecord.didDoc.didCommServices()[0]
        let invitation = ConnectionInvitationMessage(
            label: label ?? agent.agentConfig.label,
            imageUrl: imageUrl ?? agent.agentConfig.connectionImageUrl,
            recipientKeys: service.recipientKeys,
            serviceEndpoint: service.serviceEndpoint,
            routingKeys: service.routingKeys)

        connectionRecord.invitation = invitation
        try await self.connectionRepository.save(connectionRecord)

        agent.agentDelegate?.onConnectionStateChanged(connectionRecord: connectionRecord)
        return OutboundMessage(payload: invitation, connection: connectionRecord)
    }

    /**
     Process a received invitation message. The invitation message should be either a connection
     invitation or an out of band invitation. This will not accept the invitation
     or send an invitation request message. It will only create a connection record
     with all the information about the invitation stored.
     Use ``createRequest(connectionId:label:imageUrl:autoAcceptConnection:)``
     after calling this function to create a connection request.

     - Parameters:
       - invitation: optional invitation message to process.
       - outOfBandInvitation: optional out of band invitation to process.
       - routing: routing information for the connection.
       - autoAcceptConnection: whether to auto accept the connection response.
       - alias: alias for the connection.
     - Returns: new connection record.
    */
    public func processInvitation(
        _ invitation: ConnectionInvitationMessage? = nil,
        outOfBandInvitation: OutOfBandInvitation? = nil,
        routing: Routing,
        autoAcceptConnection: Bool? = nil,
        alias: String? = nil) async throws -> ConnectionRecord {

        if (invitation == nil && outOfBandInvitation == nil) || (invitation != nil && outOfBandInvitation != nil) {
            throw AriesFrameworkError.frameworkError("Either invitation or outOfBandInvitation must be set, but not both.")
        }

        if let outOfBandInvitation = outOfBandInvitation {
            if try outOfBandInvitation.invitationKey() == nil {
                throw AriesFrameworkError.frameworkError("Out of band invitation does not contain any invitation key.")
            }
        }

        let connectionRecord = try await self.createConnection(
            role: ConnectionRole.Invitee,
            state: ConnectionState.Invited,
            invitation: invitation,
            outOfBandInvitation: outOfBandInvitation,
            alias: alias,
            routing: routing,
            theirLabel: invitation?.label ?? outOfBandInvitation?.label,
            autoAcceptConnection: autoAcceptConnection,
            multiUseInvitation: false,
            imageUrl: invitation?.imageUrl ?? outOfBandInvitation?.imageUrl,
            threadId: nil)

        try await self.connectionRepository.save(connectionRecord)

        agent.agentDelegate?.onConnectionStateChanged(connectionRecord: connectionRecord)
        return connectionRecord
    }

    private func createConnection(
        role: ConnectionRole,
        state: ConnectionState,
        invitation: ConnectionInvitationMessage? = nil,
        outOfBandInvitation: OutOfBandInvitation? = nil,
        alias: String?,
        routing: Routing,
        theirLabel: String?,
        autoAcceptConnection: Bool?,
        multiUseInvitation: Bool,
        tags: Tags? = nil,
        imageUrl: String?,
        threadId: String?) async throws -> ConnectionRecord {

        let publicKey = Ed25119Sig2018(
            id: "\(routing.did)#1",
            controller: routing.did,
            publicKeyBase58: routing.verkey)

        let services = routing.endpoints.enumerated().map { (index, endpoint) in
            DidDocService.indyAgent(IndyAgentService(
                id: "\(routing.did)#IndyAgentService",
                serviceEndpoint: endpoint,
                recipientKeys: [routing.verkey],
                routingKeys: routing.routingKeys,
                priority: index)) }

        let auth = Authentication.referenced(ReferencedAuthentication(type: publicKey.type, publicKey: publicKey.id))

        let didDoc = DidDoc(
            id: routing.did,
            publicKey: [publicKey],
            service: services,
            authentication: [auth])

        let connectionRecord = ConnectionRecord(
            tags: tags,
            state: state,
            role: role,
            didDoc: didDoc,
            did: routing.did,
            verkey: routing.verkey,
            theirLabel: theirLabel,
            invitation: invitation,
            outOfBandInvitation: outOfBandInvitation,
            alias: alias,
            autoAcceptConnection: autoAcceptConnection,
            imageUrl: imageUrl,
            multiUseInvitation: multiUseInvitation,
            mediatorId: routing.mediatorId)

        return connectionRecord
    }

    /**
     Create a connection request message for the connection with the specified connection id.

     - Parameters:
       - connectionId: the id of the connection for which to create a connection request.
       - label: the label to use for the connection request.
       - imageUrl: the image url to use for the connection request.
       - autoAcceptConnection: whether to automatically accept the connection response.
     - Returns: outbound message containing connection request.
    */
    public func createRequest(
        connectionId: String,
        label: String? = nil,
        imageUrl: String? = nil,
        autoAcceptConnection: Bool? = nil) async throws -> OutboundMessage {

        var connectionRecord = try await self.connectionRepository.getById(connectionId)
        assert(connectionRecord.state == ConnectionState.Invited)
        assert(connectionRecord.role == ConnectionRole.Invitee)

        let connectionRequest = ConnectionRequestMessage(
            id: connectionId,
            label: label ?? agent.agentConfig.label,
            imageUrl: imageUrl ?? agent.agentConfig.connectionImageUrl,
            connection: Connection(did: connectionRecord.did, didDoc: connectionRecord.didDoc))

        if autoAcceptConnection != nil {
            connectionRecord.autoAcceptConnection = autoAcceptConnection
        }
        connectionRecord.threadId = connectionRequest.id
        try await updateState(connectionRecord: &connectionRecord, newState: ConnectionState.Requested)

        return OutboundMessage(payload: connectionRequest, connection: connectionRecord)
    }

    /**
     Process a received connection request message. This will not accept the connection request
     or send a connection response message. It will only update the existing connection record
     with all the new information from the connection request message. Use ``createResponse(connectionId:)``
     after calling this function to create a connection response.

     - Parameter messageContext: the message context containing the connection request message.
     - Returns: updated connection record.
    */
    public func processRequest(messageContext: InboundMessageContext) async throws -> ConnectionRecord {
        let decoder = JSONDecoder()
        let message = try decoder.decode(ConnectionRequestMessage.self, from: Data(messageContext.plaintextMessage.utf8))

        guard let recipientKey = messageContext.recipientVerkey, let senderKey = messageContext.senderVerkey else {
            throw AriesFrameworkError.frameworkError("Unable to process connection request without senderVerkey or recipientVerkey")
        }

        if message.connection.didDoc == nil {
            throw AriesFrameworkError.frameworkError("Public DIDs are not supported yet")
        }

        var connectionRecord = try await findByKeys(senderKey: senderKey, recipientKey: recipientKey)
        var outOfBandRecord: OutOfBandRecord?
        if connectionRecord == nil {
            let outOfBandRecords = await agent.outOfBandService.findAllByInvitationKey(recipientKey)
            if outOfBandRecords.isEmpty {
                connectionRecord = await findByInvitationKey(recipientKey)
                if connectionRecord == nil {
                    throw AriesFrameworkError.frameworkError("No out-of-band record or connection record found for invitation key: \(recipientKey)")
                }
            } else {
                outOfBandRecord = outOfBandRecords[0]
            }
        }

        if connectionRecord == nil || connectionRecord!.multiUseInvitation {
            connectionRecord = try await createConnection(
                role: .Inviter,
                state: .Invited,
                invitation: connectionRecord?.invitation,
                outOfBandInvitation: outOfBandRecord?.outOfBandInvitation,
                alias: nil,
                routing: agent.mediationRecipient.getRouting(),
                theirLabel: message.label,
                autoAcceptConnection: connectionRecord?.autoAcceptConnection ?? outOfBandRecord?.autoAcceptConnection,
                multiUseInvitation: true,
                imageUrl: message.imageUrl,
                threadId: message.threadId)

            try await self.connectionRepository.save(connectionRecord!)
        }

        connectionRecord!.theirDidDoc = message.connection.didDoc
        connectionRecord!.theirLabel = message.label
        connectionRecord!.threadId = message.id
        connectionRecord!.theirDid = message.connection.did
        connectionRecord!.imageUrl = message.imageUrl

        if connectionRecord!.theirKey() == nil {
            throw AriesFrameworkError.frameworkError("Connection with id \(connectionRecord!.id) has no recipient keys.")
        }

        try await updateState(connectionRecord: &connectionRecord!, newState: .Requested)
        return connectionRecord!
    }

    /**
     Create a connection response message for the connection with the specified connection id.

     - Parameter connectionId: the id of the connection for which to create a connection response.
     - Returns: outbound message containing connection response.
    */
    public func createResponse(connectionId: String) async throws -> OutboundMessage {
        var connectionRecord = try await connectionRepository.getById(connectionId)
        assert(connectionRecord.state == ConnectionState.Requested)
        assert(connectionRecord.role == ConnectionRole.Inviter)
        guard let threadId = connectionRecord.threadId else {
            throw AriesFrameworkError.frameworkError("Connection record with id \(connectionRecord.id) has no thread id.")
        }

        let connection = Connection(did: connectionRecord.did, didDoc: connectionRecord.didDoc)
        let encoder = JSONEncoder()
        let connectionJson = try encoder.encode(connection)

        let signingKey = connectionRecord.getTags()["invitationKey"] ?? connectionRecord.verkey
        let signature = try await SignatureDecorator.signData(data: connectionJson, wallet: agent.wallet, verkey: signingKey)
        let connectionResponse = ConnectionResponseMessage(connectionSig: signature)
        connectionResponse.thread = ThreadDecorator(threadId: threadId)

        try await updateState(connectionRecord: &connectionRecord, newState: .Responded)

        return OutboundMessage(payload: connectionResponse, connection: connectionRecord)
    }

    /**
     Process a received connection response message. This will not accept the connection response
     or send a connection acknowledgement message. It will only update the existing connection record
     with all the new information from the connection response message. Use ``createTrustPing(connectionId:responseRequested:comment:)``
     after calling this function to create a trust ping message.

     - Parameter messageContext: the message context containing a connection response message.
     - Returns: updated connection record.
    */
    public func processResponse(messageContext: InboundMessageContext) async throws -> ConnectionRecord {
        let decoder = JSONDecoder()
        let message = try decoder.decode(ConnectionResponseMessage.self, from: Data(messageContext.plaintextMessage.utf8))

        var connectionRecord: ConnectionRecord!
        do {
            connectionRecord = try await getByThreadId(message.threadId)
        } catch {
            throw AriesFrameworkError.frameworkError("Unable to process connection response: connection for threadId: \(message.threadId) not found")
        }
        assert(connectionRecord.state == ConnectionState.Requested)
        assert(connectionRecord.role == ConnectionRole.Invitee)

        var connection: Connection
        do {
            connection = try await message.connectionSig.unpackConnection()
        } catch {
            throw AriesFrameworkError.frameworkError("Unable to process connection response: \(error.localizedDescription)")
        }

        let signerVerkey = message.connectionSig.signer
        let invitationKey = connectionRecord.getTags()["invitationKey"]
        if signerVerkey != invitationKey {
            throw AriesFrameworkError.frameworkError("Connection object in connection response message is not signed with same key as recipient key in invitation expected=\(String(describing: invitationKey)) received=\(signerVerkey)")
        }

        connectionRecord.theirDid = connection.did
        connectionRecord.theirDidDoc = connection.didDoc
        connectionRecord.threadId = message.threadId

        try await updateState(connectionRecord: &connectionRecord, newState: ConnectionState.Responded)
        return connectionRecord
    }

    /**
     Create a trust ping message for the connection with the specified connection id.

     By default a trust ping message should elicit a response. If this is not desired the
     `responseRequested` parameter can be set to `false`.

     - Parameters:
       - connectionId: the id of the connection for which to create a trust ping message.
       - responseRequested: whether to request a response from the recipient. Default is true.
       - comment: the comment to include in the trust ping message.
     - Returns: outbound message containing trust ping message.
    */
    public func createTrustPing(connectionId: String, responseRequested: Bool? = nil, comment: String? = nil) async throws -> OutboundMessage {
        var connectionRecord = try await self.connectionRepository.getById(connectionId)
        assert(connectionRecord.state == ConnectionState.Responded || connectionRecord.state == ConnectionState.Complete)
        let trustPing = TrustPingMessage(comment: comment, responseRequested: responseRequested ?? true)

        if connectionRecord.state != ConnectionState.Complete {
            try await updateState(connectionRecord: &connectionRecord, newState: ConnectionState.Complete)
        }

        return OutboundMessage(payload: trustPing, connection: connectionRecord)
    }

    func updateState(connectionRecord: inout ConnectionRecord, newState: ConnectionState) async throws {
        connectionRecord.state = newState
        try await self.connectionRepository.update(connectionRecord)
        if newState == ConnectionState.Complete {
            finishConnectionWaiter()
        }
        agent.agentDelegate?.onConnectionStateChanged(connectionRecord: connectionRecord)
    }

    func fetchState(connectionRecord: ConnectionRecord) async throws -> ConnectionState {
        if connectionRecord.state == ConnectionState.Complete {
            return connectionRecord.state
        }

        let connection = try await connectionRepository.getById(connectionRecord.id)
        return connection.state
    }

    /**
     Find a connection by invitation key. If there are multiple connections with the same invitation key,
     the first one will be returned.

     - Parameter key: the invitation key to search for.
     - Returns: the connection record, if found.
    */
    public func findByInvitationKey(_ key: String) async -> ConnectionRecord? {
        let connections = await self.connectionRepository.findByQuery("""
            {"invitationKey": "\(key)"}
            """)
        if connections.count == 0 {
            return nil
        }
        return connections[0]
    }

    /**
     Find all connections by invitation key.

     - Parameter key: the invitation key to search for.
     - Returns: the connection record, if found.
    */
    public func findAllByInvitationKey(_ key: String) async -> [ConnectionRecord] {
        return await self.connectionRepository.findByQuery("""
            {"invitationKey": "\(key)"}
            """)
    }

    /**
     Retrieve a connection record by thread id.

     - Parameter threadId: the thread id.
     - Returns: the connection record.
    */
    public func getByThreadId(_ threadId: String) async throws -> ConnectionRecord {
        return try await self.connectionRepository.getSingleByQuery("""
            {"threadId": "\(threadId)"}
            """)
    }

    /**
     Find connection by sender key and recipient key.

     - Parameters:
       - senderKey: the sender key of the received message.
       - recipientKey: the recipient key of the received message, which is this agent's verkey.
     - Returns: the connection record, if found.
    */
    public func findByKeys(senderKey: String, recipientKey: String) async throws -> ConnectionRecord? {
        return try await self.connectionRepository.findSingleByQuery("""
            {"verkey": "\(recipientKey)", "theirKey": "\(senderKey)"}
            """)
    }

    func waitForConnection() async throws -> Bool {
        return try await connectionWaiter.wait()
    }

    private func finishConnectionWaiter() {
        connectionWaiter.finish()
    }
}
