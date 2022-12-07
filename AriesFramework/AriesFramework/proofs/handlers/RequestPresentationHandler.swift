
import Foundation

class RequestPresentationHandler: MessageHandler {
    let agent: Agent
    let messageType = RequestPresentationMessage.type

    init(agent: Agent) {
        self.agent = agent
    }

    func handle(messageContext: InboundMessageContext) async throws -> OutboundMessage? {
        let proofRecord = try await agent.proofService.processRequest(messageContext: messageContext)

        if (proofRecord.autoAcceptProof != nil && proofRecord.autoAcceptProof! == .always) || agent.agentConfig.autoAcceptProof == .always {
            return try await createPresentation(record: proofRecord, messageContext: messageContext)
        }

        return nil
    }

    func createPresentation(record: ProofExchangeRecord, messageContext: InboundMessageContext) async throws -> OutboundMessage? {
        let retrievedCredentials = try await agent.proofs.getRequestedCredentialsForProofRequest(proofRecordId: record.id)
        let requestedCredentials = try await agent.proofService.autoSelectCredentialsForProofRequest(retrievedCredentials: retrievedCredentials)

        let (message, _) = try await agent.proofService.createPresentation(proofRecord: record, requestedCredentials: requestedCredentials)
        return OutboundMessage(payload: message, connection: messageContext.connection!)
    }
}
