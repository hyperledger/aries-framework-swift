
import Foundation
import os

class ProblemReportHandler: MessageHandler {
    let agent: Agent
    let messageType: String
    let logger = Logger(subsystem: "AriesFramework", category: "ProblemReportHandler")

    init(agent: Agent, messageType: String) {
        self.agent = agent
        self.messageType = messageType
    }

    func handle(messageContext: InboundMessageContext) async throws -> OutboundMessage? {
        let message = try JSONDecoder().decode(BaseProblemReportMessage.self, from: Data(messageContext.plaintextMessage.utf8))
        logger.debug("Received problem report: \(message.description.en)")
        agent.agentDelegate?.onProblemReportReceived(message: message)
        return nil
    }
}