
import Foundation
import os

public class HttpOutboundTransport: OutboundTransport {
    let logger = Logger(subsystem: "AriesFramework", category: "HttpOutboundTransport")
    let agent: Agent

    public init(_ agent: Agent) {
        self.agent = agent
    }

    public func sendPackage(_ package: OutboundPackage) async throws {
        logger.debug("Sending outbound message to endpoint \(package.endpoint)")

        var request = URLRequest(url: URL(string: package.endpoint)!)
        request.httpMethod = "POST"
        request.httpBody = try JSONEncoder().encode(package.payload)
        request.addValue(DidCommMimeType.V1.rawValue, forHTTPHeaderField: "Content-Type")

        let (data, response) = try await URLSession.shared.data(for: request)
        // swiftlint:disable:next force_cast
        logger.debug("response with status code: \((response as! HTTPURLResponse).statusCode)")

        if data.count > 0 {
            let encryptedMessage = try JSONDecoder().decode(EncryptedMessage.self, from: data)
            try await agent.receiveMessage(encryptedMessage)
        } else if package.responseRequested {
            logger.debug("Requested response but got no data. Will initiate message pickup if necessary.")
            DispatchQueue.main.asyncAfter(deadline: .now() + agent.agentConfig.mediatorEmptyReturnRetryInterval) { [self] in
                Task {
                    try await self.agent.mediationRecipient.pickupMessages()
                }
            }
        } else {
            logger.debug("No data received")
        }
    }
}
