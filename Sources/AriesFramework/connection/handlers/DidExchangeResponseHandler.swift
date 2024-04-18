
import Foundation

class DidExchangeResponseHandler: MessageHandler {
    let agent: Agent
    let messageType = DidExchangeResponseMessage.type

    init(agent: Agent) {
        self.agent = agent
    }

    func handle(messageContext: InboundMessageContext) async throws -> OutboundMessage? {
        let connection = try await agent.didExchangeService.processResponse(messageContext: messageContext)

        if connection.autoAcceptConnection ?? agent.agentConfig.autoAcceptConnections {
            return try await agent.didExchangeService.createComplete(connectionId: connection.id)
        }

        return nil
    }
}
