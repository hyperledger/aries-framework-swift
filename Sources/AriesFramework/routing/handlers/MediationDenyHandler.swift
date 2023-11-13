
import Foundation

class MediationDenyHandler: MessageHandler {
    let agent: Agent
    let messageType = MediationDenyMessage.type

    init(agent: Agent) {
        self.agent = agent
    }

    func handle(messageContext: InboundMessageContext) async throws -> OutboundMessage? {
        try await agent.mediationRecipient.processMediationDeny(messageContext: messageContext)
        return nil
    }
}
