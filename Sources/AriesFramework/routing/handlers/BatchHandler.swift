
import Foundation

class BatchHandler: MessageHandler {
    let agent: Agent
    let messageType = BatchMessage.type

    init(agent: Agent) {
        self.agent = agent
    }

    func handle(messageContext: InboundMessageContext) async throws -> OutboundMessage? {
        try await agent.mediationRecipient.processBatchMessage(messageContext: messageContext)
        return nil
    }
}
