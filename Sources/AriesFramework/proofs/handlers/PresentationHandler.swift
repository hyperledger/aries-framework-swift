
import Foundation

class PresentationHandler: MessageHandler {
    let agent: Agent
    let messageType = PresentationMessage.type

    init(agent: Agent) {
        self.agent = agent
    }

    func handle(messageContext: InboundMessageContext) async throws -> OutboundMessage? {
        let proofRecord = try await agent.proofService.processPresentation(messageContext: messageContext)

        if (proofRecord.autoAcceptProof != nil && proofRecord.autoAcceptProof! == .always) || agent.agentConfig.autoAcceptProof == .always {
            let (message, _) = try await agent.proofService.createAck(proofRecord: proofRecord)
            return OutboundMessage(payload: message, connection: messageContext.connection!)
        }

        return nil
    }
}
