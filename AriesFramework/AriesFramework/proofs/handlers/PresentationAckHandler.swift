
import Foundation

class PresentationAckHandler: MessageHandler {
    let agent: Agent
    let messageType = PresentationAckMessage.type

    init(agent: Agent) {
        self.agent = agent
    }

    func handle(messageContext: InboundMessageContext) async throws -> OutboundMessage? {
        _ = try await agent.proofService.processAck(messageContext: messageContext)

        return nil
    }
}
