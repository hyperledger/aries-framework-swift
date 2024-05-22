
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
        if let oobInvitation = message.connection?.outOfBandInvitation ?? message.outOfBand?.outOfBandInvitation {
            var thread = agentMessage.thread ?? ThreadDecorator()
            if thread.parentThreadId == nil {
                thread.parentThreadId = oobInvitation.id
                agentMessage.thread = thread
            }
        }

        return agentMessage
    }

    func getSenderVerkey(for message: OutboundMessage) async throws -> String {
        if let connectionVerkey = message.connection?.verkey {
            return connectionVerkey
        }
        return try await agent.mediationRecipient.getRouting().verkey
    }

    func canSendMessage(to service: DidDocService, with endpointPrefix: String?) -> Bool {
        if let prefix = endpointPrefix, !service.serviceEndpoint.hasPrefix(prefix) {
            return false
        }
        if endpointPrefix == nil, outboundTransportForEndpoint(service.serviceEndpoint) == nil {
            return false
        }
        return true
    }

    public func send(message: OutboundMessage, endpointPrefix: String? = nil) async throws {
        let agentMessage = await decorateMessage(message)
        let services = try await findDidCommServices(message)
        guard !services.isEmpty else {
            logger.error("Cannot find outbound service for message of type \(agentMessage.type)")
            throw AriesFrameworkError.frameworkError("No services found for message of type \(agentMessage.type)")
        }

        let senderVerkey = try await getSenderVerkey(for: message)

        for service in services {
            guard canSendMessage(to: service, with: endpointPrefix) else {
                logger.debug("Skipping unsupported endpoint \(service.serviceEndpoint)")
                continue
            }
            do {
                try await sendMessageToService(
                    message: agentMessage,
                    service: service,
                    senderKey: senderVerkey,
                    connectionId: message.connection?.id)
                return
            } catch {
                logger.debug("Sending outbound message to service \(service.serviceEndpoint) failed with the following error: \(error.localizedDescription)")
            }
        }

        let endpoints = services.compactMap { $0.serviceEndpoint }
        throw AriesFrameworkError.frameworkError("Message is not delivered to the following services. \(endpoints)")
    }

    func findDidCommServicesFromConnection(_ connection: ConnectionRecord) throws -> [DidDocService]? {
        if let theirDidDoc = connection.theirDidDoc {
            return theirDidDoc.didCommServices()
        }

        if let invitation = connection.invitation, let serviceEndpoint = invitation.serviceEndpoint {
            let service = DidCommService(
                id: "\(connection.id)-invitation",
                serviceEndpoint: serviceEndpoint,
                recipientKeys: invitation.recipientKeys ?? [],
                routingKeys: invitation.routingKeys ?? []
            )
            return [DidDocService.didComm(service)]
        }

        if let outOfBandInvitation = connection.outOfBandInvitation {
            return try outOfBandInvitation.services.compactMap { try $0.asDidDocService() }
        }

        return nil
    }

    func findDidCommServicesFromOutOfBand(_ outOfBand: OutOfBandRecord) throws -> [DidDocService]? {
        let invitation = outOfBand.outOfBandInvitation
        return try invitation.services.compactMap { try $0.asDidDocService() }
    }

    func findDidCommServices(_ outboundMessage: OutboundMessage) async throws -> [DidDocService] {
        if let connection = outboundMessage.connection {
            if let services = try findDidCommServicesFromConnection(connection) {
                return services
            }
        }
        if let outOfBand = outboundMessage.outOfBand {
            if let services = try findDidCommServicesFromOutOfBand(outOfBand) {
                return services
            }
        }

        return []
    }

    func sendMessageToService(message: AgentMessage, service: DidDocService, senderKey: String, connectionId: String?) async throws {
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

    func packMessage(_ message: AgentMessage, keys: EnvelopeKeys, endpoint: String, connectionId: String?) async throws -> OutboundPackage {
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
