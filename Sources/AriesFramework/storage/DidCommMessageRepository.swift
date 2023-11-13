
import Foundation

public class DidCommMessageRepository: Repository<DidCommMessageRecord> {
    public override func save(_ record: DidCommMessageRecord) async throws {
        throw AriesFrameworkError.frameworkError("Do not call save() directly. We need to change the prefix of the message type before save the record.")
    }

    public func saveAgentMessage(role: DidCommMessageRole, agentMessage: AgentMessage, associatedRecordId: String) async throws {
        if self.agent.agentConfig.useLegacyDidSovPrefix {
            agentMessage.replaceNewDidCommPrefixWithLegacyDidSov()
        }
        let didCommMessageRecord = DidCommMessageRecord(
            message: agentMessage,
            role: role,
            associatedRecordId: associatedRecordId
        )

        try await super.save(didCommMessageRecord)
    }

    public func saveOrUpdateAgentMessage(role: DidCommMessageRole, agentMessage: AgentMessage, associatedRecordId: String) async throws {
        if self.agent.agentConfig.useLegacyDidSovPrefix {
            agentMessage.replaceNewDidCommPrefixWithLegacyDidSov()
        }
        let record = try await findSingleByQuery("""
            {"associatedRecordId": "\(associatedRecordId)",
            "messageType": "\(agentMessage.type)"}
            """
        )

        if var record = record {
            record.message = agentMessage.toJsonString()
            record.role = role
            try await update(record)
            return
        }

        try await saveAgentMessage(role: role, agentMessage: agentMessage, associatedRecordId: associatedRecordId)
    }

    public func getAgentMessage(associatedRecordId: String, messageType: String) async throws -> String {
        var type = messageType
        if self.agent.agentConfig.useLegacyDidSovPrefix {
            type = Dispatcher.replaceNewDidCommPrefixWithLegacyDidSov(messageType: messageType)
        }
        let record = try await getSingleByQuery("""
            {"associatedRecordId": "\(associatedRecordId)",
            "messageType": "\(type)"}
            """
        )

        return record.message
    }

    public func findAgentMessage(associatedRecordId: String, messageType: String) async throws -> String? {
        var type = messageType
        if self.agent.agentConfig.useLegacyDidSovPrefix {
            type = Dispatcher.replaceNewDidCommPrefixWithLegacyDidSov(messageType: messageType)
        }
        let record = try await findSingleByQuery("""
            {"associatedRecordId": "\(associatedRecordId)",
            "messageType": "\(type)"}
            """
        )

        return record?.message
    }
}
