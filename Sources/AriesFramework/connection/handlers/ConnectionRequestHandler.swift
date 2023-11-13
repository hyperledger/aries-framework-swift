
import Foundation

class ConnectionRequestHandler: MessageHandler {
    let agent: Agent
    let messageType = ConnectionRequestMessage.type

    init(agent: Agent) {
        self.agent = agent
    }

    func handle(messageContext: InboundMessageContext) async throws -> OutboundMessage? {
        let connectionRecord = try await agent.connectionService.processRequest(messageContext: messageContext)
        if connectionRecord.autoAcceptConnection ?? false || agent.agentConfig.autoAcceptConnections {
            return try await agent.connectionService.createResponse(connectionId: connectionRecord.id)
        }

        return nil
    }
}
