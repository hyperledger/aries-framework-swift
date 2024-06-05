
import Foundation
import os

let didCommProfiles = ["didcomm/aip1", "didcomm/aip2;env=rfc19"]

public class OutOfBandCommand {
    let agent: Agent
    let logger = Logger(subsystem: "AriesFramework", category: "OutOfBandCommand")

    init(agent: Agent, dispatcher: Dispatcher) {
        self.agent = agent
        registerHandlers(dispatcher: dispatcher)
    }

    func registerHandlers(dispatcher: Dispatcher) {
        dispatcher.registerHandler(handler: HandshakeReuseHandler(agent: agent))
        dispatcher.registerHandler(handler: HandshakeReuseAcceptedHandler(agent: agent))
    }

    /**
     Creates an outbound out-of-band record containing out-of-band invitation message defined in
     Aries RFC 0434: Out-of-Band Protocol 1.1.

     It automatically adds all supported handshake protocols by agent to `handshake_protocols`. You
     can modify this by setting `handshakeProtocols` in `config` parameter. If you want to create
     invitation without handshake, you can set `handshake` to `false`.

     If `config` parameter contains `messages` it adds them to `requests~attach` attribute.

     Agent role: sender (inviter)

     - Parameter config: configuration of how out-of-band invitation should be created.
     - Returns: out-of-band record.
    */
    public func createInvitation(config: CreateOutOfBandInvitationConfig) async throws -> OutOfBandRecord {
        let multiUseInvitation = config.multiUseInvitation ?? false
        let handshake = config.handshake ?? true
        let autoAcceptConnection = config.autoAcceptConnection ?? agent.agentConfig.autoAcceptConnections
        let messages = config.messages ?? []
        let label = config.label ?? agent.agentConfig.label
        let imageUrl = config.imageUrl ?? agent.agentConfig.connectionImageUrl

        if !handshake && messages.count == 0 {
            throw AriesFrameworkError.frameworkError(
                "One of handshake_protocols and requests~attach MUST be included in the message."
            )
        }

        if !messages.isEmpty && multiUseInvitation {
            throw AriesFrameworkError.frameworkError(
                "Attribute 'multiUseInvitation' can not be 'true' when 'messages' is defined."
            )
        }

        var handshakeProtocols: [HandshakeProtocol]?
        if handshake {
            handshakeProtocols = self.getSupportedHandshakeProtocols()
        }

        var routing: Routing! = config.routing
        if routing == nil {
            routing = try await self.agent.mediationRecipient.getRouting()
        }

        let services = try routing.endpoints.enumerated().map({ (index, endpoint) -> OutOfBandDidCommService in
            return .oobDidDocument(OutOfBandDidDocumentService(
                id: "#inline-\(index)",
                serviceEndpoint: endpoint,
                recipientKeys: try DIDParser.ConvertVerkeysToDidKeys(verkeys: [routing.verkey]),
                routingKeys: try DIDParser.ConvertVerkeysToDidKeys(verkeys: routing.routingKeys)
            ))
        })

        let outOfBandInvitation = OutOfBandInvitation(
            id: OutOfBandInvitation.generateId(),
            label: label,
            goalCode: config.goalCode,
            goal: config.goal,
            accept: didCommProfiles,
            handshakeProtocols: handshakeProtocols,
            services: services,
            imageUrl: imageUrl)

        if !messages.isEmpty {
            try messages.forEach { message in
                try outOfBandInvitation.addRequest(message: message)
            }
            if handshake == false {
                // For connection-less exchange. Create a fake connection in inviter side.
                let connectionRecord = try await agent.connectionService.createConnection(
                    role: .Inviter,
                    state: .Complete,
                    outOfBandInvitation: outOfBandInvitation,
                    alias: nil,
                    routing: routing,
                    theirLabel: nil,
                    autoAcceptConnection: true,
                    multiUseInvitation: false,
                    tags: nil,
                    imageUrl: nil,
                    threadId: nil)
                try await agent.connectionRepository.save(connectionRecord)
            }
        }

        var outOfBandRecord = OutOfBandRecord(
            id: OutOfBandRecord.generateId(),
            createdAt: Date(),
            outOfBandInvitation: outOfBandInvitation,
            role: .Sender,
            state: .AwaitResponse,
            reusable: multiUseInvitation,
            autoAcceptConnection: autoAcceptConnection)
        if let message = messages.first, handshake == false {
            outOfBandRecord.tags = ["attach_thread_id": message.threadId]
        }

        try await self.agent.outOfBandRepository.save(outOfBandRecord)
        agent.agentDelegate?.onOutOfBandStateChanged(outOfBandRecord: outOfBandRecord)
        logger.debug("OutOfBandInvitation created with id: \(outOfBandInvitation.id)")

        return outOfBandRecord
    }

    /**
     Parses URL, decodes invitation and calls `receiveInvitation` with parsed invitation message.

     Agent role: receiver (invitee)

     - Parameters:
        - url: url containing a base64 encoded invitation to receive.
        - config: configuration of how out-of-band invitation should be received.
     - Returns: out-of-band record and connection record if one has been created.
    */
    public func receiveInvitationFromUrl(_ url: String, config: ReceiveOutOfBandInvitationConfig? = nil) async throws -> (OutOfBandRecord?, ConnectionRecord?) {
        let (outOfBandInvitation, invitation) = try await parseInvitationShortUrl(url)
        if invitation != nil {
            let connection = try await self.agent.connections.receiveInvitation(invitation!,
                autoAcceptConnection: config?.autoAcceptConnection, alias: config?.alias)
            return (nil, connection)
        }

        return try await receiveInvitation(outOfBandInvitation!, config: config)
    }

    /**
     Parses URL containing encoded invitation and returns invitation message. Compatible with
     parsing shortened URLs.

     - Parameter url: url containing either a base64url encoded invitation or shortened URL.
     - Returns: out-of-band invitation and connection invitation if one has been parsed.
    */
    public func parseInvitationShortUrl(_ url: String) async throws -> (OutOfBandInvitation?, ConnectionInvitationMessage?) {
        return try await InvitationUrlParser.parseUrl(url)
    }

    /**
     Creates inbound out-of-band record and assigns out-of-band invitation message to it if the
     message is valid. It automatically passes out-of-band invitation for further processing to
     `acceptInvitation` method. If you don't want to do that you can set `autoAcceptInvitation`
     attribute in `config` parameter to `false` and accept the message later by calling
     `acceptInvitation`.

     It supports both OOB (Aries RFC 0434: Out-of-Band Protocol 1.1) and Connection Invitation
     (0160: Connection Protocol).

     Agent role: receiver (invitee)

     - Parameters:
        - invitation: OutOfBandInvitation to receive.
        - config: configuration of how out-of-band invitation should be received.
     - Returns: out-of-band record and connection record if one has been created.
    */
    public func receiveInvitation(_ invitation: OutOfBandInvitation, config: ReceiveOutOfBandInvitationConfig? = nil) async throws -> (OutOfBandRecord, ConnectionRecord?) {
        let autoAcceptInvitation = config?.autoAcceptInvitation ?? true
        let autoAcceptConnection = config?.autoAcceptConnection ?? true
        let reuseConnection = config?.reuseConnection ?? false
        let label = config?.label ?? agent.agentConfig.label
        let alias = config?.alias
        let imageUrl = config?.imageUrl ?? agent.agentConfig.connectionImageUrl

        let messages = try invitation.getRequests()

        if invitation.handshakeProtocols?.count ?? 0 == 0 && messages.count == 0 {
            throw AriesFrameworkError.frameworkError(
                "One of handshake_protocols and requests~attach MUST be included in the message."
            )
        }

        let previousRecord = try await agent.outOfBandRepository.findByInvitationId(invitation.id)
        if previousRecord != nil {
            throw AriesFrameworkError.frameworkError(
                "An out of band record with invitation \(invitation.id) already exists. Invitations should have a unique id."
            )
        }

        if try invitation.fingerprints().isEmpty {
            throw AriesFrameworkError.frameworkError(
                "Invitation does not contain any valid service object."
            )
        }

        let outOfBandRecord = OutOfBandRecord(
            id: OutOfBandRecord.generateId(),
            createdAt: Date(),
            outOfBandInvitation: invitation,
            role: .Receiver,
            state: .Initial,
            reusable: false,
            autoAcceptConnection: autoAcceptConnection)
        try await self.agent.outOfBandRepository.save(outOfBandRecord)
        agent.agentDelegate?.onOutOfBandStateChanged(outOfBandRecord: outOfBandRecord)

        if autoAcceptInvitation {
            let acceptConfig = ReceiveOutOfBandInvitationConfig(
                label: label,
                alias: alias,
                imageUrl: imageUrl,
                autoAcceptConnection: autoAcceptConnection,
                reuseConnection: reuseConnection,
                routing: config?.routing)
            return try await self.acceptInvitation(outOfBandId: outOfBandRecord.id, config: acceptConfig)
        }

        return (outOfBandRecord, nil)
    }

    /**
     Creates a connection if the out-of-band invitation message contains `handshake_protocols`
     attribute, except for the case when connection already exists and `reuseConnection` is enabled.

     It passes first supported message from `requests~attach` attribute to the agent, except for the
     case reuse of connection is applied when it just sends `handshake-reuse` message to existing
     connection.

     Agent role: receiver (invitee)

     - Parameters:
        - outOfBandId: out-of-band record id to accept.
        - config: configuration of how out-of-band invitation should be received.
     - Returns: out-of-band record and connection record if one has been created.
    */
    public func acceptInvitation(outOfBandId: String, config: ReceiveOutOfBandInvitationConfig? = nil) async throws -> (OutOfBandRecord, ConnectionRecord?) {
        var outOfBandRecord = try await agent.outOfBandService.getById(outOfBandId)
        let existingConnection = try await findExistingConnection(outOfBandInvitation: outOfBandRecord.outOfBandInvitation)

        try await agent.outOfBandService.updateState(outOfBandRecord: &outOfBandRecord, newState: .PrepareResponse)

        let messages = try outOfBandRecord.outOfBandInvitation.getRequests()
        let handshakeProtocols = outOfBandRecord.outOfBandInvitation.handshakeProtocols ?? []

        var connectionRecord: ConnectionRecord?
        if existingConnection != nil && config?.reuseConnection ?? true {
            if messages.count > 0 {
                logger.debug("Skip handshake and reuse existing connection \(existingConnection!.id)")
                connectionRecord = existingConnection
            } else {
                logger.debug("Start handshake to reuse connection.")
                let isHandshakeReuseSuccessful = try await handleHandshakeReuse(outOfBandRecord: outOfBandRecord, connectionRecord: existingConnection!)
                if isHandshakeReuseSuccessful {
                    connectionRecord = existingConnection
                } else {
                    logger.warning("Handshake reuse failed. Not using existing connection \(existingConnection!.id)")
                }
            }
        }

        let handshakeProtocol = try selectHandshakeProtocol(handshakeProtocols)
        if connectionRecord == nil {
            logger.debug("Creating new connection.")
            connectionRecord = try await agent.connections.acceptOutOfBandInvitation(
                outOfBandRecord: outOfBandRecord,
                handshakeProtocol: handshakeProtocol,
                config: config)
        }

        if handshakeProtocol != nil {
            try await waitForConnection(connection: connectionRecord!, handshakeProtocol: handshakeProtocol!)
        }
        connectionRecord = try await agent.connectionRepository.getById(connectionRecord!.id)
        if !outOfBandRecord.reusable {
            try await agent.outOfBandService.updateState(outOfBandRecord: &outOfBandRecord, newState: .Done)
        }

        if messages.count > 0 {
            try await processMessages(messages, connectionRecord: connectionRecord!)
        }
        return (outOfBandRecord, connectionRecord)
    }

    private func waitForConnection(connection: ConnectionRecord, handshakeProtocol: HandshakeProtocol) async throws {
        if try await agent.connectionService.fetchState(connectionRecord: connection) != .Complete {
            var result = false
            switch handshakeProtocol {
            case .Connections:
                result = try await agent.connectionService.waitForConnection()
            case .DidExchange10, .DidExchange11:
                result = try await agent.didExchangeService.waitForConnection()
            }
            if !result {
                throw AriesFrameworkError.frameworkError("Connection timed out.")
            }
        }
    }

    private func processMessages(_ messages: [String], connectionRecord: ConnectionRecord) async throws {
        let message = messages.first(where: { message in
            guard let agentMessage = try? MessageReceiver.decodeAgentMessage(plaintextMessage: message) else {
                logger.warning("Cannot decode agent message: \(message)")
                return false
            }
            return agent.dispatcher.canHandleMessage(agentMessage)
        })

        if message == nil {
            throw AriesFrameworkError.frameworkError("There is no message in requests~attach supported by agent.")
        }

        try await agent.messageReceiver.receivePlaintextMessage(message!, connection: connectionRecord)
    }

    private func handleHandshakeReuse(outOfBandRecord: OutOfBandRecord, connectionRecord: ConnectionRecord) async throws -> Bool {
        let reuseMessage = try await agent.outOfBandService.createHandShakeReuse(outOfBandRecord: outOfBandRecord, connectionRecord: connectionRecord)
        let message = OutboundMessage(payload: reuseMessage, connection: connectionRecord)
        try await agent.messageSender.send(message: message)

        if try await agent.outOfBandRepository.getById(outOfBandRecord.id).state != .Done {
            let result = try await agent.outOfBandService.waitForHandshakeReuse()
            return result
        }

        return true
    }

    private func findExistingConnection(outOfBandInvitation: OutOfBandInvitation) async throws -> ConnectionRecord? {
        guard let invitationKey = try outOfBandInvitation.invitationKey() else {
            return nil
        }
        let connections = await agent.connectionService.findAllByInvitationKey(invitationKey)

        if connections.count == 0 {
            return nil
        }
        return connections.first(where: { $0.isReady() })
    }

    private func getSupportedHandshakeProtocols() -> [HandshakeProtocol] {
        return [.Connections, .DidExchange11]
    }

    private func assertHandshakeProtocols(_ handshakeProtocols: [HandshakeProtocol]) throws {
        if !areHandshakeProtocolsSupported(handshakeProtocols) {
            let supportedProtocols = getSupportedHandshakeProtocols()
            throw AriesFrameworkError.frameworkError(
                "Handshake protocols [\(handshakeProtocols)] are not supported. Supported protocols are [\(supportedProtocols)]"
            )
        }
    }

    private func areHandshakeProtocolsSupported(_ handshakeProtocols: [HandshakeProtocol]) -> Bool {
        let supportedProtocols = getSupportedHandshakeProtocols()
        return handshakeProtocols.allSatisfy({ (p) -> Bool in
            return supportedProtocols.contains(p)
        })
    }

    private func selectHandshakeProtocol(_ handshakeProtocols: [HandshakeProtocol]) throws -> HandshakeProtocol? {
        if handshakeProtocols.isEmpty {
            return nil
        }
        let supportedProtocols = getSupportedHandshakeProtocols()
        if handshakeProtocols.contains(agent.agentConfig.preferredHandshakeProtocol) &&
            supportedProtocols.contains(agent.agentConfig.preferredHandshakeProtocol) {
            return agent.agentConfig.preferredHandshakeProtocol
        }
        for protocolName in handshakeProtocols where supportedProtocols.contains(protocolName) {
            return protocolName
        }
        throw AriesFrameworkError.frameworkError(
            "None of the provided handshake protocols [\(handshakeProtocols)] are supported. Supported protocols are [\(supportedProtocols)]"
        )
    }
}
