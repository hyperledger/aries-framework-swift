
import Foundation

class OfferCredentialHandler: MessageHandler {
    let agent: Agent
    let messageType = OfferCredentialMessage.type

    init(agent: Agent) {
        self.agent = agent
    }

    func handle(messageContext: InboundMessageContext) async throws -> OutboundMessage? {
        let credentialRecord = try await agent.credentialService.processOffer(messageContext: messageContext)

        if (credentialRecord.autoAcceptCredential != nil && credentialRecord.autoAcceptCredential! == .always) || agent.agentConfig.autoAcceptCredential == .always {
            let message = try await agent.credentialService.createRequest(options: AcceptOfferOptions(credentialRecordId: credentialRecord.id))
            
            var outOfBand = messageContext.outOfBand
            if outOfBand == nil {
                outOfBand = try await agent.outOfBandRepository.findByTags(credentialRecord.tags)
            }
            return OutboundMessage(payload: message, connection: messageContext.connection, outOfBand: outOfBand)
        }

        return nil
    }
}
