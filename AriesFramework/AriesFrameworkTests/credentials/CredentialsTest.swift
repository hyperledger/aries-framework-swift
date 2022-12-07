// swiftlint:disable force_cast

import XCTest
@testable import AriesFramework

class CredentialsTest: XCTestCase {
    var faberAgent: Agent!
    var aliceAgent: Agent!
    var credDefId: String!
    var faberConnection: ConnectionRecord!
    var aliceConnection: ConnectionRecord!

    let credentialPreview = CredentialPreview.fromDictionary([
        "name": "John",
        "age": "99"
    ])

    override func setUp() async throws {
        try await super.setUp()

        (faberAgent, aliceAgent, credDefId, faberConnection, aliceConnection) = try await TestHelper.setupCredentialTests()
    }

    override func tearDown() async throws {
        try await faberAgent?.reset()
        try await aliceAgent?.reset()
        try await super.tearDown()
    }

    func getCredentialRecord(for agent: Agent, threadId: String) async throws -> CredentialExchangeRecord {
        let credentialRecord = try await agent.credentialRepository.getByThreadAndConnectionId(threadId: threadId, connectionId: nil)
        return credentialRecord
    }

    func testCredentialOffer() async throws {
        // Faber starts with credential offer to Alice.
        var faberCredentialRecord = try await faberAgent.credentials.offerCredential(
            options: CreateOfferOptions(
                connection: faberConnection,
                credentialDefinitionId: credDefId,
                attributes: credentialPreview.attributes,
                comment: "Offer to Alice"))
        try await Task.sleep(nanoseconds: UInt64(0.1 * SECOND))

        let threadId = faberCredentialRecord.threadId
        var aliceCredentialRecord = try await getCredentialRecord(for: aliceAgent, threadId: threadId)
        XCTAssertTrue(aliceCredentialRecord.state == .OfferReceived)

        _ = try await aliceAgent.credentials.acceptOffer(
            options: AcceptOfferOptions(credentialRecordId: aliceCredentialRecord.id))
        try await Task.sleep(nanoseconds: UInt64(0.1 * SECOND))

        faberCredentialRecord = try await getCredentialRecord(for: faberAgent, threadId: threadId)
        XCTAssertTrue(faberCredentialRecord.state == .RequestReceived)

        _ = try await faberAgent.credentials.acceptRequest(
            options: AcceptRequestOptions(credentialRecordId: faberCredentialRecord.id))
        try await Task.sleep(nanoseconds: UInt64(0.1 * SECOND))

        aliceCredentialRecord = try await getCredentialRecord(for: aliceAgent, threadId: threadId)
        XCTAssertTrue(aliceCredentialRecord.state == .CredentialReceived)

        _ = try await aliceAgent.credentials.acceptCredential(
            options: AcceptCredentialOptions(credentialRecordId: aliceCredentialRecord.id))
        try await Task.sleep(nanoseconds: UInt64(0.1 * SECOND))

        aliceCredentialRecord = try await getCredentialRecord(for: aliceAgent, threadId: threadId)
        XCTAssertTrue(aliceCredentialRecord.state == .Done)
        faberCredentialRecord = try await getCredentialRecord(for: faberAgent, threadId: threadId)
        XCTAssertTrue(faberCredentialRecord.state == .Done)

        let credentialMessage = try await aliceAgent.credentials.findCredentialMessage(credentialRecordId: aliceCredentialRecord.id)
        XCTAssertNotNil(credentialMessage)
        let attachment = credentialMessage?.getCredentialAttachmentById(IssueCredentialMessage.INDY_CREDENTIAL_ATTACHMENT_ID)
        XCTAssertNotNil(attachment)
        if let credentialJson = try attachment?.getDataAsString() {
            let credential = try JSONSerialization.jsonObject(with: credentialJson.data(using: .utf8)!, options: []) as! [String: Any]
            let values = credential["values"] as! [String: Any]
            let age = values["age"] as! [String: String]
            XCTAssertEqual(age["raw"], "99")
            XCTAssertEqual(age["encoded"], "99")

            let name = values["name"] as! [String: String]
            XCTAssertEqual(name["raw"], "John")
            XCTAssertEqual(name["encoded"], "76355713903561865866741292988746191972523015098789458240077478826513114743258")
        } else {
            XCTFail("attachment not found")
        }
    }

    func testAutoAcceptAgentConfig() async throws {
        aliceAgent.agentConfig.autoAcceptCredential = .always
        faberAgent.agentConfig.autoAcceptCredential = .always

        var faberCredentialRecord = try await faberAgent.credentials.offerCredential(
            options: CreateOfferOptions(
                connection: faberConnection,
                credentialDefinitionId: credDefId,
                attributes: credentialPreview.attributes,
                comment: "Offer to Alice"))
        try await Task.sleep(nanoseconds: UInt64(1 * SECOND)) // Need enough time to finish exchange a credential.

        let threadId = faberCredentialRecord.threadId
        let aliceCredentialRecord = try await getCredentialRecord(for: aliceAgent, threadId: threadId)
        faberCredentialRecord = try await getCredentialRecord(for: faberAgent, threadId: threadId)

        XCTAssertTrue(aliceCredentialRecord.state == .Done)
        XCTAssertTrue(faberCredentialRecord.state == .Done)
    }

    func testAutoAcceptOptions() async throws {
        // Only faberAgent auto accepts.
        var faberCredentialRecord = try await faberAgent.credentials.offerCredential(
            options: CreateOfferOptions(
                connection: faberConnection,
                credentialDefinitionId: credDefId,
                attributes: credentialPreview.attributes,
                autoAcceptCredential: .always,
                comment: "Offer to Alice"))
        try await Task.sleep(nanoseconds: UInt64(0.1 * SECOND))

        let threadId = faberCredentialRecord.threadId
        var aliceCredentialRecord = try await getCredentialRecord(for: aliceAgent, threadId: threadId)
        faberCredentialRecord = try await getCredentialRecord(for: faberAgent, threadId: threadId)

        XCTAssertTrue(aliceCredentialRecord.state == .OfferReceived)
        XCTAssertTrue(faberCredentialRecord.state == .OfferSent)

        // aliceAgent auto accepts too.
        _ = try await aliceAgent.credentials.acceptOffer(
            options: AcceptOfferOptions(credentialRecordId: aliceCredentialRecord.id, autoAcceptCredential: .always))
        try await Task.sleep(nanoseconds: UInt64(1 * SECOND))

        aliceCredentialRecord = try await getCredentialRecord(for: aliceAgent, threadId: threadId)
        faberCredentialRecord = try await getCredentialRecord(for: faberAgent, threadId: threadId)
        XCTAssertTrue(aliceCredentialRecord.state == .Done)
        XCTAssertTrue(faberCredentialRecord.state == .Done)
    }
}
