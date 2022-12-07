
import Foundation

class TrustPingMessageHandler: MessageHandler {
    let agent: Agent
    let messageType = TrustPingMessage.type

    init(agent: Agent) {
        self.agent = agent
    }

    func handle(messageContext: InboundMessageContext) async throws -> OutboundMessage? {
        if var connection = messageContext.connection, connection.state == .Responded {
            try await agent.connectionService.updateState(connectionRecord: &connection, newState: .Complete)
        }
        return nil
    }
}
