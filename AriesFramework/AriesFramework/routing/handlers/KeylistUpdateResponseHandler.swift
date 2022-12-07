
import Foundation

class KeylistUpdateResponseHandler: MessageHandler {
    let agent: Agent
    let messageType = KeylistUpdateResponseMessage.type

    init(agent: Agent) {
        self.agent = agent
    }

    func handle(messageContext: InboundMessageContext) async throws -> OutboundMessage? {
        try await agent.mediationRecipient.processKeylistUpdateResults(messageContext: messageContext)
        return nil
    }
}
