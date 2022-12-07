
import Foundation

class HandshakeReuseAcceptedHandler: MessageHandler {
    let agent: Agent
    let messageType = HandshakeReuseAcceptedMessage.type

    init(agent: Agent) {
        self.agent = agent
    }

    func handle(messageContext: InboundMessageContext) async throws -> OutboundMessage? {
        _ = try messageContext.assertReadyConnection()
        try await agent.outOfBandService.processHandshakeReuseAccepted(messageContext: messageContext)

        return nil
    }
}
