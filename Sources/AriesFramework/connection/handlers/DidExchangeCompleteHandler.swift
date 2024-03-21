
import Foundation

class DidExchangeCompleteHandler: MessageHandler {
    let agent: Agent
    let messageType = DidExchangeCompleteMessage.type

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
