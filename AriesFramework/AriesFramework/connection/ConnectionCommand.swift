
import Foundation
import os

public class ConnectionCommand {
    let agent: Agent
    let logger = Logger(subsystem: "AriesFramework", category: "ConnectionCommand")

    init(agent: Agent, dispatcher: Dispatcher) {
        self.agent = agent
        registerHandlers(dispatcher: dispatcher)
    }

    func registerHandlers(dispatcher: Dispatcher) {
        dispatcher.registerHandler(handler: ConnectionRequestHandler(agent: agent))
        dispatcher.registerHandler(handler: ConnectionResponseHandler(agent: agent))
        dispatcher.registerHandler(handler: TrustPingMessageHandler(agent: agent))
    }

    /**
     Create a new connection invitation message.

     - Parameters:
        - autoAcceptConnection: whether to auto accept the connection response.
        - alias: alias to use for the connection.
        - multiUseInvitation: whether to create a multi use invitation.
        - imageUrl: image url for the connection invitation.
     - Returns: `OutboundMessage` containing connection invitation message as payload.
    */
    public func createConnection(
        autoAcceptConnection: Bool? = nil,
        alias: String? = nil,
        multiUseInvitation: Bool? = nil,
        label: String? = nil,
        imageUrl: String? = nil) async throws -> OutboundMessage {

        let routing = try await agent.mediationRecipient.getRouting()
        let message = try await agent.connectionService.createInvitation(
            routing: routing,
            autoAcceptConnection: autoAcceptConnection,
            alias: alias,
            multiUseInvitation: multiUseInvitation,
            label: label,
            imageUrl: imageUrl)

        return message
    }

    /**
     Receive connection invitation as invitee and create connection. If auto accepting is enabled
     via either the config passed in the function or the global agent config, a connection
     request message will be send.

     - Parameters:
        - invitation: optional connection invitation message to receive.
        - outOfBandInvitation: optional out of band invitation message to receive.
        - autoAcceptConnection: whether to auto accept the connection response.
        - alias: alias to use for the connection.
     - Returns: new connection record.
    */
    public func receiveInvitation(
        _ invitation: ConnectionInvitationMessage? = nil,
        outOfBandInvitation: OutOfBandInvitation? = nil,
        autoAcceptConnection: Bool? = nil,
        alias: String? = nil) async throws -> ConnectionRecord {

        logger.debug("Receive connection invitation")
        var connection = try await agent.connectionService.processInvitation(invitation,
            outOfBandInvitation: outOfBandInvitation,
            routing: agent.mediationRecipient.getRouting(),
            autoAcceptConnection: autoAcceptConnection,
            alias: alias)
        if connection.autoAcceptConnection ?? agent.agentConfig.autoAcceptConnections {
            connection = try await acceptInvitation(connectionId: connection.id, autoAcceptConnection: autoAcceptConnection)
        }
        return connection
    }

    /**
     Receive connection invitation as invitee and create connection. If auto accepting is enabled
     via either the config passed in the function or the global agent config, a connection
     request message will be send.

     - Parameters:
        - invitationUrl: url containing a base64url encoded invitation to receive.
        - autoAcceptConnection: whether to auto accept the connection response.
        - alias: alias to use for the connection.
     - Returns: new connection record.
    */
    public func receiveInvitationFromUrl(
        _ invitationUrl: String,
        autoAcceptConnection: Bool? = nil,
        alias: String? = nil) async throws -> ConnectionRecord {

        let invitation = try ConnectionInvitationMessage.fromUrl(invitationUrl)
        return try await receiveInvitation(invitation, autoAcceptConnection: autoAcceptConnection, alias: alias)
    }

    /**
     Accept a connection invitation as invitee (by sending a connection request message) for the connection with the specified connection id.
     This is not needed when auto accepting of connections is enabled.

     - Parameters:
        - connectionId: id of the connection to accept.
        - autoAcceptConnection: whether to auto accept the connection response.
     - Returns: new connection record.
    */
    public func acceptInvitation(connectionId: String, autoAcceptConnection: Bool?) async throws -> ConnectionRecord {
        logger.debug("Accept connection invitation")
        let message = try await agent.connectionService.createRequest(connectionId: connectionId, autoAcceptConnection: autoAcceptConnection)
        try await agent.messageSender.send(message: message)
        return message.connection
    }

    func acceptOutOfBandInvitation(outOfBandRecord: OutOfBandRecord, config: ReceiveOutOfBandInvitationConfig?) async throws -> ConnectionRecord {
        let connection = try await receiveInvitation(outOfBandInvitation: outOfBandRecord.outOfBandInvitation,
            autoAcceptConnection: false, alias: config?.alias)
        let message = try await agent.connectionService.createRequest(connectionId: connection.id,
            label: config?.label,
            imageUrl: config?.imageUrl,
            autoAcceptConnection: config?.autoAcceptConnection)
        try await agent.messageSender.send(message: message)
        return message.connection
    }
}
