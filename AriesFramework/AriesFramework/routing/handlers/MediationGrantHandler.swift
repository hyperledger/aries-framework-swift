
import Foundation

class MediationGrantHandler: MessageHandler {
    let agent: Agent
    let messageType = MediationGrantMessage.type

    init(agent: Agent) {
        self.agent = agent
    }

    func handle(messageContext: InboundMessageContext) async throws -> OutboundMessage? {
        try await agent.mediationRecipient.processMediationGrant(messageContext: messageContext)
        return nil
    }
}
