
import Foundation

class HandshakeReuseHandler: MessageHandler {
    let agent: Agent
    let messageType = HandshakeReuseMessage.type

    init(agent: Agent) {
        self.agent = agent
    }

    func handle(messageContext: InboundMessageContext) async throws -> OutboundMessage? {
        let connectionRecord = try messageContext.assertReadyConnection()
        let message = try await agent.outOfBandService.processHandshakeReuse(messageContext: messageContext)

        return OutboundMessage(payload: message, connection: connectionRecord)
    }
}
