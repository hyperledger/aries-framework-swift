
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
            let message = try MessageReceiver.decodeAgentMessage(plaintextMessage: decryptedMessage.plaintextMessage)
            let connection = try await findConnection(decryptedMessage: decryptedMessage, message: message)
            let messageContext = InboundMessageContext(message: message,
                                                       plaintextMessage: decryptedMessage.plaintextMessage,
                                                       connection: connection,
                                                       senderVerkey: decryptedMessage.senderKey,
                                                       recipientVerkey: decryptedMessage.recipientKey)
            try await agent.dispatcher.dispatch(messageContext: messageContext)
        } catch {
            logger.error("failed to receive encrypted message: \(error)")
        }
    }

    func receivePlaintextMessage(_ plaintextMessage: String, connection: ConnectionRecord) async throws {
        do {
            let message = try MessageReceiver.decodeAgentMessage(plaintextMessage: plaintextMessage)
            let messageContext = InboundMessageContext(message: message,
                                                       plaintextMessage: plaintextMessage,
                                                       connection: connection,
                                                       senderVerkey: nil,
                                                       recipientVerkey: nil)
            try await agent.dispatcher.dispatch(messageContext: messageContext)
        } catch {
            logger.error("failed to receive plaintext message: \(error)")
        }
    }

    func findConnection(decryptedMessage: DecryptedMessageContext, message: AgentMessage) async throws -> ConnectionRecord? {
        var connection = try await findConnectionByMessageKeys(decryptedMessage: decryptedMessage)
        if connection == nil {
            connection = try await findConnectionByMessageThreadId(message: message)
            if connection != nil {
                // If a connection is found by the message thread id, then this message is
                // a connection-less exchange and recipient is the oob inviter.
                // To be able to respond to the sender, sender's information should be updated
                // based on incomming message because the oob inviter created a fake connection.
                updateConnectionTheirDidDoc(&connection!, senderKey: decryptedMessage.senderKey)
            }
        }
        return connection
    }

    func findConnectionByMessageKeys(decryptedMessage: DecryptedMessageContext) async throws -> ConnectionRecord? {
        let connectionRecord = try await agent.connectionService.findByKeys(senderKey: decryptedMessage.senderKey ?? "",
                                                                            recipientKey: decryptedMessage.recipientKey ?? "")
        return connectionRecord
    }

    func findConnectionByMessageThreadId(message: AgentMessage) async throws -> ConnectionRecord? {
        guard let threadId = message.thread?.threadId else {
            return nil
        }
        guard let oobRecord = try await agent.outOfBandService.findByAttachmentThreadId(threadId) else {
            return nil
        }
        let connection = try await agent.connectionService.findByInvitationKey(oobRecord.outOfBandInvitation.invitationKey()!)
        return connection
    }

    func updateConnectionTheirDidDoc(_ connection: inout ConnectionRecord, senderKey: String?) {
        guard let senderKey = senderKey else {
            return
        }
        let service = DidCommService(
            id: "\(connection.id)#1",
            serviceEndpoint: DID_COMM_TRANSPORT_QUEUE,
            recipientKeys: [senderKey]
        ).asDidDocService()

        var theirDidDoc = DidDoc(
            id: senderKey,
            publicKey: [],
            service: [service],
            authentication: []
        )
        connection.theirDidDoc = theirDidDoc
    }

    static func decodeAgentMessage(plaintextMessage: String) throws -> AgentMessage {
        let data = plaintextMessage.data(using: .utf8)!
        let decoder = JSONDecoder()
        let agentMessage = try decoder.decode(AgentMessage.self, from: data)
        return agentMessage
    }
}
