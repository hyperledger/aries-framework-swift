
import Foundation
import os

public class MessageSender {
    let agent: Agent
    var defaultOutboundTransport: OutboundTransport?
    let httpOutboundTransport: HttpOutboundTransport
    let wsOutboundTransport: WsOutboundTransport
    let logger = Logger(subsystem: "AriesFramework", category: "MessageSender")

    public init(agent: Agent) {
        self.agent = agent
        self.httpOutboundTransport = HttpOutboundTransport(agent)
        self.wsOutboundTransport = WsOutboundTransport(agent)
    }

    public func setOutboundTransport(_ outboundTransport: OutboundTransport) {
        self.defaultOutboundTransport = outboundTransport
    }

    func outboundTransportForEndpoint(_ endpoint: String) -> OutboundTransport? {
        if defaultOutboundTransport != nil {
            return defaultOutboundTransport
        } else if endpoint.hasPrefix("http://") || endpoint.hasPrefix("https://") {
            return httpOutboundTransport
        } else if endpoint.hasPrefix("ws://") || endpoint.hasPrefix("wss://") {
            return wsOutboundTransport
        } else {
            return nil
        }
    }

    func decorateMessage(_ message: OutboundMessage) -> AgentMessage {
        let agentMessage = message.payload
        if agent.agentConfig.useLegacyDidSovPrefix {
            agentMessage.replaceNewDidCommPrefixWithLegacyDidSov()
        }

        if agentMessage.transport == nil {
            agentMessage.transport = TransportDecorator(returnRoute: "all")
        }

        // If the message is a response to an out-of-band invitation, set the parent thread id.
        // We should not override the parent thread id if it is already set, because it may be
        // a response to a different invitation. For example, a handshake-reuse message sent
        // over an existing connection created from a different out-of-band invitation.
        if let oobInvitation = message.connection.outOfBandInvitation {
            var thread = agentMessage.thread ?? ThreadDecorator()
            if thread.parentThreadId == nil {
                thread.parentThreadId = oobInvitation.id
                agentMessage.thread = thread
            }
        }

        return agentMessage
    }

    public func send(message: OutboundMessage, endpointPrefix: String? = nil) async throws {
        let agentMessage = decorateMessage(message)
        let services = try findDidCommServices(connection: message.connection)
        if services.isEmpty {
            logger.error("Cannot find services for message of type \(agentMessage.type)")
        }

        for service in services {
            if endpointPrefix != nil && !service.serviceEndpoint.hasPrefix(endpointPrefix!) {
                continue
            }
            logger.debug("Send outbound message of type \(agentMessage.type) to endpoint \(service.serviceEndpoint)")
            if endpointPrefix == nil && outboundTransportForEndpoint(service.serviceEndpoint) == nil {
                logger.debug("endpoint is not supported")
                continue
            }
            do {
                try await sendMessageToService(
                    message: agentMessage, service: service,
                    senderKey: message.connection.verkey,
                    connectionId: message.connection.id)
                return
            } catch {
                logger.debug("Sending outbound message to service \(service.serviceEndpoint) failed with the following error: \(error.localizedDescription)")
            }
        }

        throw AriesFrameworkError.frameworkError("Message is undeliverable to connection \(message.connection.id)")
    }

    func findDidCommServices(connection: ConnectionRecord) throws -> [DidDocService] {
        if (connection.theirDidDoc) != nil {
            return connection.theirDidDoc!.didCommServices()
        }

        if connection.role == ConnectionRole.Invitee {
            if let invitation = connection.invitation, let serviceEndpoint = invitation.serviceEndpoint {
                let service = DidCommService(
                    id: "\(connection.id)-invitation", serviceEndpoint: serviceEndpoint,
                    recipientKeys: invitation.recipientKeys ?? [],
                    routingKeys: invitation.routingKeys ?? [])
                return [DidDocService.didComm(service)]
            }
            if let invitation = connection.outOfBandInvitation {
                return try invitation.services.compactMap { try $0.asDidDocService() }
            }
        }

        if connection.role == ConnectionRole.Inviter {
            if let invitation = connection.outOfBandInvitation {
                return try invitation.services.compactMap { try $0.asDidDocService() }
            }
        }

        return []
    }

    func sendMessageToService(message: AgentMessage, service: DidDocService, senderKey: String, connectionId: String) async throws {
        let keys = EnvelopeKeys(
            recipientKeys: service.recipientKeys,
            routingKeys: service.routingKeys ?? [],
            senderKey: senderKey)

        let outboundPackage = try await packMessage(message, keys: keys, endpoint: service.serviceEndpoint, connectionId: connectionId)
        guard let outboundTransport = outboundTransportForEndpoint(service.serviceEndpoint) else {
            throw AriesFrameworkError.frameworkError("No outbound transport found for endpoint \(service.serviceEndpoint)")
        }
        try await outboundTransport.sendPackage(outboundPackage)
    }

    func packMessage(_ message: AgentMessage, keys: EnvelopeKeys, endpoint: String, connectionId: String) async throws -> OutboundPackage {
        var encryptedMessage = try await agent.wallet.pack(message: message, recipientKeys: keys.recipientKeys, senderVerkey: keys.senderKey)

        var recipientKeys = keys.recipientKeys
        for routingKey in keys.routingKeys {
            let forwardMessage = ForwardMessage(to: recipientKeys[0], message: encryptedMessage)
            if agent.agentConfig.useLegacyDidSovPrefix {
                forwardMessage.replaceNewDidCommPrefixWithLegacyDidSov()
            }
            recipientKeys = [routingKey]
            encryptedMessage = try await agent.wallet.pack(message: forwardMessage, recipientKeys: recipientKeys, senderVerkey: keys.senderKey)
        }

        return OutboundPackage(
            payload: encryptedMessage,
            responseRequested: message.requestResponse(),
            endpoint: endpoint,
            connectionId: connectionId)
    }

    func close() async {
        await wsOutboundTransport.closeSocket()
    }
}
