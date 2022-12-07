
import XCTest
import Indy
@testable import AriesFramework

class DidCommMessageRepositoryTest: XCTestCase {
    var agent: Agent!
    var repository: DidCommMessageRepository!
    var invitation: ConnectionInvitationMessage!

    override func setUp() async throws {
        try await super.setUp()

        let config = try TestHelper.getBaseConfig(name: "alice")
        agent = Agent(agentConfig: config, agentDelegate: nil)
        repository = agent.didCommMessageRepository
        try await agent.initialize()

        invitation = ConnectionInvitationMessage(
            id: "test-invitation",
            label: "test",
            recipientKeys: ["recipientKeyOne", "recipientKeyTwo"],
            serviceEndpoint: "https://example.com"
        )
    }

    override func tearDown() async throws {
        try await agent.reset()
        try await super.tearDown()
    }

    func getRecord() -> DidCommMessageRecord {
        return DidCommMessageRecord(
            message: invitation,
            role: .Receiver,
            associatedRecordId: "04a2c382-999e-4de9-a1d2-9dec0b2fa5e4"
        )
    }

    func testGetAgentMessage() async throws {
        let record = getRecord()
        try await repository.saveAgentMessage(role: .Receiver, agentMessage: invitation, associatedRecordId: record.associatedRecordId!)

        let message = try await repository.getAgentMessage(associatedRecordId: record.associatedRecordId!, messageType: ConnectionInvitationMessage.type)
        let decoded = try JSONDecoder().decode(ConnectionInvitationMessage.self, from: Data(message.utf8))

        XCTAssertEqual(decoded.id, invitation.id)
        XCTAssertEqual(decoded.label, invitation.label)
        XCTAssertEqual(decoded.serviceEndpoint, invitation.serviceEndpoint)
    }

    func testFindAgentMessage() async throws {
        let record = getRecord()
        try await repository.saveAgentMessage(role: .Receiver, agentMessage: invitation, associatedRecordId: record.associatedRecordId!)

        let message = try await repository.findAgentMessage(associatedRecordId: record.associatedRecordId!, messageType: ConnectionInvitationMessage.type)!
        let decoded = try JSONDecoder().decode(ConnectionInvitationMessage.self, from: Data(message.utf8))

        XCTAssertEqual(decoded.id, invitation.id)
        XCTAssertEqual(decoded.label, invitation.label)
        XCTAssertEqual(decoded.serviceEndpoint, invitation.serviceEndpoint)

        let notFound = try await repository.findAgentMessage(associatedRecordId: "non-found", messageType: ConnectionInvitationMessage.type)
        XCTAssertNil(notFound)
    }

    func testSaveAgentMessage() async throws {
        let record = getRecord()
        try await repository.saveAgentMessage(role: .Receiver, agentMessage: invitation, associatedRecordId: record.associatedRecordId!)

        let message = try await repository.getAgentMessage(associatedRecordId: record.associatedRecordId!, messageType: ConnectionInvitationMessage.type)
        let decoded = try JSONDecoder().decode(ConnectionInvitationMessage.self, from: Data(message.utf8))

        XCTAssertEqual(decoded.id, invitation.id)
        XCTAssertEqual(decoded.label, invitation.label)
        XCTAssertEqual(decoded.serviceEndpoint, invitation.serviceEndpoint)

        let invitationUpdate = ConnectionInvitationMessage(
            id: "test-invitation-update",
            label: "test-update",
            recipientKeys: ["recipientKeyOne", "recipientKeyTwo"],
            serviceEndpoint: "https://example.com"
        )

        try await repository.saveOrUpdateAgentMessage(role: .Sender, agentMessage: invitationUpdate, associatedRecordId: record.associatedRecordId!)
        let updatedMessage = try await repository.getAgentMessage(associatedRecordId: record.associatedRecordId!, messageType: ConnectionInvitationMessage.type)
        let decodedUpdate = try JSONDecoder().decode(ConnectionInvitationMessage.self, from: Data(updatedMessage.utf8))

        XCTAssertEqual(decodedUpdate.id, invitationUpdate.id)
        XCTAssertEqual(decodedUpdate.label, invitationUpdate.label)

        var type = ConnectionInvitationMessage.type
        if self.agent.agentConfig.useLegacyDidSovPrefix {
            type = Dispatcher.replaceNewDidCommPrefixWithLegacyDidSov(messageType: type)
        }
        let updatedRecord = try await repository.findSingleByQuery("""
            {"associatedRecordId": "\(record.associatedRecordId!)",
            "messageType": "\(type)"}
            """
        )!
        XCTAssertEqual(updatedRecord.message, invitationUpdate.toJsonString())
        XCTAssertEqual(updatedRecord.role, .Sender)
    }
}
