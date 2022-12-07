import XCTest
@testable import AriesFramework

class ProofsTest: XCTestCase {
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

    func getProofRecord(for agent: Agent, threadId: String) async throws -> ProofExchangeRecord {
        let proofRecord = try await agent.proofRepository.getByThreadAndConnectionId(threadId: threadId, connectionId: nil)
        return proofRecord
    }

    func issueCredential() async throws {
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

        XCTAssertEqual(aliceCredentialRecord.state, .Done)
        XCTAssertEqual(faberCredentialRecord.state, .Done)
    }

    func getProofRequest() async throws -> ProofRequest {
        let attributes = ["name": ProofAttributeInfo(
            name: "name", names: nil, nonRevoked: nil,
            restrictions: [AttributeFilter(credentialDefinitionId: credDefId)])]
        let predicates = ["age": ProofPredicateInfo(
            name: "age", nonRevoked: nil, predicateType: .GreaterThanOrEqualTo, predicateValue: 50,
            restrictions: [AttributeFilter(credentialDefinitionId: credDefId)])]

        let nonce = try await ProofService.generateProofRequestNonce()
        return ProofRequest(nonce: nonce, requestedAttributes: attributes, requestedPredicates: predicates)
    }

    func getFailingProofRequest() async throws -> ProofRequest {
        let attributes = ["name": ProofAttributeInfo(
            name: "name", names: nil, nonRevoked: nil,
            restrictions: [AttributeFilter(credentialDefinitionId: credDefId)])]
        let predicates = ["age": ProofPredicateInfo(
            name: "age", nonRevoked: nil, predicateType: .LessThan, predicateValue: 50,
            restrictions: [AttributeFilter(credentialDefinitionId: credDefId)])]

        let nonce = try await ProofService.generateProofRequestNonce()
        return ProofRequest(nonce: nonce, requestedAttributes: attributes, requestedPredicates: predicates)
    }

    func testProofRequest() async throws {
        try await issueCredential()
        let proofRequest = try await getProofRequest()
        var faberProofRecord = try await faberAgent.proofs.requestProof(connectionId: faberConnection.id, proofRequest: proofRequest)
        try await Task.sleep(nanoseconds: UInt64(0.1 * SECOND))

        let threadId = faberProofRecord.threadId
        var aliceProofRecord = try await getProofRecord(for: aliceAgent, threadId: threadId)
        XCTAssertEqual(aliceProofRecord.state, .RequestReceived)

        let retrievedCredentials = try await aliceAgent.proofs.getRequestedCredentialsForProofRequest(proofRecordId: aliceProofRecord.id)
        let requestedCredentials = try await aliceAgent.proofService.autoSelectCredentialsForProofRequest(retrievedCredentials: retrievedCredentials)
        aliceProofRecord = try await aliceAgent.proofs.acceptRequest(proofRecordId: aliceProofRecord.id, requestedCredentials: requestedCredentials)
        try await Task.sleep(nanoseconds: UInt64(0.1 * SECOND))

        faberProofRecord = try await getProofRecord(for: faberAgent, threadId: threadId)
        XCTAssertEqual(faberProofRecord.state, .PresentationReceived)
        XCTAssertEqual(faberProofRecord.isVerified, true)

        faberProofRecord = try await faberAgent.proofs.acceptPresentation(proofRecordId: faberProofRecord.id)
        try await Task.sleep(nanoseconds: UInt64(0.1 * SECOND))

        aliceProofRecord = try await getProofRecord(for: aliceAgent, threadId: threadId)
        XCTAssertEqual(aliceProofRecord.state, .Done)
        XCTAssertEqual(faberProofRecord.state, .Done)
    }

    func testAutoAcceptAgentConfig() async throws {
        aliceAgent.agentConfig.autoAcceptProof = .always
        faberAgent.agentConfig.autoAcceptProof = .always

        try await issueCredential()
        let proofRequest = try await getProofRequest()
        var faberProofRecord = try await faberAgent.proofs.requestProof(connectionId: faberConnection.id, proofRequest: proofRequest)
        try await Task.sleep(nanoseconds: UInt64(1 * SECOND))

        let threadId = faberProofRecord.threadId
        let aliceProofRecord = try await getProofRecord(for: aliceAgent, threadId: threadId)
        faberProofRecord = try await getProofRecord(for: faberAgent, threadId: threadId)

        XCTAssertEqual(aliceProofRecord.state, .Done)
        XCTAssertEqual(faberProofRecord.state, .Done)
        XCTAssertEqual(faberProofRecord.isVerified, true)
    }

    func testProofWithoutCredential() async throws {
        // issueCredential() is omitted.

        let proofRequest = try await getProofRequest()
        let faberProofRecord = try await faberAgent.proofs.requestProof(connectionId: faberConnection.id, proofRequest: proofRequest)
        try await Task.sleep(nanoseconds: UInt64(0.1 * SECOND))

        let threadId = faberProofRecord.threadId
        let aliceProofRecord = try await getProofRecord(for: aliceAgent, threadId: threadId)
        XCTAssertEqual(aliceProofRecord.state, .RequestReceived)

        let retrievedCredentials = try await aliceAgent.proofs.getRequestedCredentialsForProofRequest(proofRecordId: aliceProofRecord.id)

        XCTAssertEqual(retrievedCredentials.requestedAttributes["name"]!.count, 0)
        XCTAssertEqual(retrievedCredentials.requestedPredicates["age"]!.count, 0)

        do {
            _ = try await aliceAgent.proofService.autoSelectCredentialsForProofRequest(retrievedCredentials: retrievedCredentials)
            XCTFail("Expected error")
        } catch {
            // Expected error
        }
    }

    func testProofWithFailingPredicates() async throws {
        try await issueCredential()
        let proofRequest = try await getFailingProofRequest()
        let faberProofRecord = try await faberAgent.proofs.requestProof(connectionId: faberConnection.id, proofRequest: proofRequest)
        try await Task.sleep(nanoseconds: UInt64(0.1 * SECOND))

        let threadId = faberProofRecord.threadId
        let aliceProofRecord = try await getProofRecord(for: aliceAgent, threadId: threadId)
        XCTAssertEqual(aliceProofRecord.state, .RequestReceived)

        let retrievedCredentials = try await aliceAgent.proofs.getRequestedCredentialsForProofRequest(proofRecordId: aliceProofRecord.id)

        XCTAssertEqual(retrievedCredentials.requestedAttributes["name"]!.count, 1)
        XCTAssertEqual(retrievedCredentials.requestedPredicates["age"]!.count, 0)

        do {
            _ = try await aliceAgent.proofService.autoSelectCredentialsForProofRequest(retrievedCredentials: retrievedCredentials)
            XCTFail("Expected error")
        } catch {
            // Expected error
        }
    }
}
