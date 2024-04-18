
import Foundation

class DidExchangeRequestHandler: MessageHandler {
    let agent: Agent
    let messageType = DidExchangeRequestMessage.type

    init(agent: Agent) {
        self.agent = agent
    }

    func handle(messageContext: InboundMessageContext) async throws -> OutboundMessage? {
        let connectionRecord = try await agent.didExchangeService.processRequest(messageContext: messageContext)
        if connectionRecord.autoAcceptConnection ?? false || agent.agentConfig.autoAcceptConnections {
            return try await agent.didExchangeService.createResponse(connectionId: connectionRecord.id)
        }

        return nil
    }
}
