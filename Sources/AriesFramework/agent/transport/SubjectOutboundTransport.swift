
import Foundation
import os

class SubjectOutboundTransport: OutboundTransport {
    let logger = Logger(subsystem: "AriesFramework", category: "SubjectOutboundTransport")
    let subject: Agent

    public init(subject: Agent) {
        self.subject = subject
    }

    public func sendPackage(_ package: OutboundPackage) async throws {
        logger.debug("Sending outbound message to subject \(self.subject.agentConfig.label)")
        try await subject.receiveMessage(package.payload)
    }
}
