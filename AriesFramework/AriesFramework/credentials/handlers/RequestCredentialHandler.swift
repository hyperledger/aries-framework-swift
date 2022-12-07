
import Foundation

class RequestCredentialHandler: MessageHandler {
    let agent: Agent
    let messageType = RequestCredentialMessage.type

    init(agent: Agent) {
        self.agent = agent
    }

    func handle(messageContext: InboundMessageContext) async throws -> OutboundMessage? {
        let credentialRecord = try await agent.credentialService.processRequest(messageContext: messageContext)

        if (credentialRecord.autoAcceptCredential != nil && credentialRecord.autoAcceptCredential! == .always) || agent.agentConfig.autoAcceptCredential == .always {
            let message = try await agent.credentialService.createCredential(options: AcceptRequestOptions(credentialRecordId: credentialRecord.id))
            return OutboundMessage(payload: message, connection: messageContext.connection!)
        }

        return nil
    }
}
