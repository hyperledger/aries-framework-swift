
import Foundation

class IssueCredentialHandler: MessageHandler {
    let agent: Agent
    let messageType = IssueCredentialMessage.type

    init(agent: Agent) {
        self.agent = agent
    }

    func handle(messageContext: InboundMessageContext) async throws -> OutboundMessage? {
        let credentialRecord = try await agent.credentialService.processCredential(messageContext: messageContext)

        if (credentialRecord.autoAcceptCredential != nil && credentialRecord.autoAcceptCredential! == .always) || agent.agentConfig.autoAcceptCredential == .always {
            let message = try await agent.credentialService.createAck(options: AcceptCredentialOptions(credentialRecordId: credentialRecord.id))

            var outOfBand = messageContext.outOfBand
            if outOfBand == nil {
                outOfBand = try await agent.outOfBandRepository.findByTags(credentialRecord.tags)
            }
            return OutboundMessage(payload: message, connection: messageContext.connection, outOfBand: outOfBand)

        }

        return nil
    }
}
