
import Foundation
import os

public class Dispatcher {
    let agent: Agent
    let logger = Logger(subsystem: "AriesFramework", category: "Dispatcher")
    var handlers: [String: MessageHandler] = [:]

    init(agent: Agent) {
        self.agent = agent
    }

    public func registerHandler(handler: MessageHandler) {
        handlers[handler.messageType] = handler
        handlers[Dispatcher.replaceNewDidCommPrefixWithLegacyDidSov(messageType: handler.messageType)] = handler
    }

    func dispatch(messageContext: InboundMessageContext) async throws {
        logger.debug("Dispatching message of type: \(messageContext.message.type)")
        guard let handler = handlers[messageContext.message.type] else {
            throw AriesFrameworkError.frameworkError("No handler for message type: \(messageContext.message.type)")
        }

        do {
            if let outboundMessage = try await handler.handle(messageContext: messageContext) {
                logger.debug("Finishing dispatch with message of type: \(outboundMessage.payload.type)")
                Task {
                    try await agent.messageSender.send(message: outboundMessage)
                }
            } else {
                logger.debug("Finishing dispatch without response")
            }
        } catch {
            logger.error("Failed to dispatch message of type: \(messageContext.message.type)")
            throw error
        }
    }

    func getHandlerForType(messageType: String) -> MessageHandler? {
        return handlers[messageType]
    }

    func canHandleMessage(_ message: AgentMessage) -> Bool {
        return handlers[message.type] != nil
    }

    static func replaceNewDidCommPrefixWithLegacyDidSov(messageType: String) -> String {
        let didSovPrefix = "did:sov:BzCbsNYhMrjHiqZDTUASHg;spec"
        let didCommPrefix = "https://didcomm.org"

        if messageType.starts(with: didCommPrefix) {
            return messageType.replacingOccurrences(of: didCommPrefix, with: didSovPrefix)
        }

        return messageType
    }
}
