
import Foundation
import os

public class MessageReceiver {
    let logger = Logger(subsystem: "AriesFramework", category: "MessageReceiver")
    let agent: Agent

    public init(agent: Agent) {
        self.agent = agent
    }

    func receiveMessage(_ encryptedMessage: EncryptedMessage) async throws {
        do {
            let decryptedMessage = try await agent.wallet.unpack(encryptedMessage: encryptedMessage)
            let connection = try await findConnectionByMessageKeys(decryptedMessage: decryptedMessage)
            let message = try decodeAgentMessage(plaintextMessage: decryptedMessage.plaintextMessage)
            let messageContext = InboundMessageContext(message: message,
                                                       plaintextMessage: decryptedMessage.plaintextMessage,
                                                       connection: connection,
                                                       senderVerkey: decryptedMessage.senderKey,
                                                       recipientVerkey: decryptedMessage.recipientKey)
            try await agent.dispatcher.dispatch(messageContext: messageContext)
        } catch {
            logger.error("failed to receive message: \(error)")
        }
    }

    func receivePlaintextMessage(_ plaintextMessage: String, connection: ConnectionRecord) async throws {
        do {
            let message = try decodeAgentMessage(plaintextMessage: plaintextMessage)
            let messageContext = InboundMessageContext(message: message,
                                                       plaintextMessage: plaintextMessage,
                                                       connection: connection,
                                                       senderVerkey: nil,
                                                       recipientVerkey: nil)
            try await agent.dispatcher.dispatch(messageContext: messageContext)
        } catch {
            logger.error("failed to receive message: \(error)")
        }
    }

    func findConnectionByMessageKeys(decryptedMessage: DecryptedMessageContext) async throws -> ConnectionRecord? {
        let connectionRecord = try await agent.connectionService.findByKeys(senderKey: decryptedMessage.senderKey ?? "",
                                                                            recipientKey: decryptedMessage.recipientKey ?? "")
        return connectionRecord
    }

    func decodeAgentMessage(plaintextMessage: String) throws -> AgentMessage {
        let data = plaintextMessage.data(using: .utf8)!
        let decoder = JSONDecoder()
        let agentMessage = try decoder.decode(AgentMessage.self, from: data)
        return agentMessage
    }
}
