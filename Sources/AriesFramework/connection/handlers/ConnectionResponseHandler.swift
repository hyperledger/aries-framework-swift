
import Foundation

class ConnectionResponseHandler: MessageHandler {
    let agent: Agent
    let messageType = ConnectionResponseMessage.type

    init(agent: Agent) {
        self.agent = agent
    }

    func handle(messageContext: InboundMessageContext) async throws -> OutboundMessage? {
        let connection = try await agent.connectionService.processResponse(messageContext: messageContext)

        if connection.autoAcceptConnection ?? agent.agentConfig.autoAcceptConnections {
            return try await agent.connectionService.createTrustPing(connectionId: connection.id, responseRequested: false)
        }

        return nil
    }
}
