
import XCTest
@testable import AriesFramework

class ProblemReportsTest: XCTestCase {
    var faberAgent: Agent!
    var aliceAgent: Agent!
    var credDefId: String!
    var faberConnection: ConnectionRecord!
    var aliceConnection: ConnectionRecord!

    let credentialPreview = CredentialPreview.fromDictionary([
        "name": "John",
        "sex": "Male",
        "age": "99"
    ])

    class TestDelegate: AgentDelegate {
        let expectation: TestHelper.XCTestExpectation
        let threadId: String
        init(expectation: TestHelper.XCTestExpectation, threadId: String) {
            self.expectation = expectation
            self.threadId = threadId
        }
        func onProblemReportReceived(message: BaseProblemReportMessage) {
            XCTAssertEqual(message.threadId, threadId)
            expectation.fulfill()
        }
    }

    override func setUp() async throws {
        try await super.setUp()

        (faberAgent, aliceAgent, faberConnection, aliceConnection) = try await TestHelper.setupCredentialTests()
        credDefId = try await TestHelper.prepareForIssuance(faberAgent, ["name", "sex", "age"])
    }

    override func tearDown() async throws {
        try await faberAgent?.reset()
        try await aliceAgent?.reset()
        try await super.tearDown()
    }

    func getCredentialRecord(for agent: Agent, threadId: String) async throws -> CredentialExchangeRecord {
        let credentialRecord = try await agent.credentialExchangeRepository.getByThreadAndConnectionId(threadId: threadId, connectionId: nil)
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

        let nonce = try ProofService.generateProofRequestNonce()
        return ProofRequest(nonce: nonce, requestedAttributes: attributes, requestedPredicates: predicates)
    }

    func testCredentialDeclinedProblemReport() async throws {
        let faberCredentialRecord = try await faberAgent.credentials.offerCredential(
            options: CreateOfferOptions(
                connection: faberConnection,
                credentialDefinitionId: credDefId,
                attributes: credentialPreview.attributes,
                comment: "Offer to Alice"))

        let threadId = faberCredentialRecord.threadId
        let aliceCredentialRecord = try await getCredentialRecord(for: aliceAgent, threadId: threadId)
        XCTAssertEqual(aliceCredentialRecord.state, .OfferReceived)

        let expectation = TestHelper.expectation(description: "Problem report received")
        faberAgent.agentDelegate = TestDelegate(expectation: expectation, threadId: threadId)

        _ = try await aliceAgent.credentials.declineOffer(credentialRecordId: aliceCredentialRecord.id)
        try await TestHelper.wait(for: expectation, timeout: 5)
    }

    func testProofDeclinedProblemReport() async throws {
        try await issueCredential()

        let proofRequest = try await getProofRequest()
        let faberProofRecord = try await faberAgent.proofs.requestProof(
            connectionId: faberConnection.id,
            proofRequest: proofRequest,
            comment: "Request from Alice")

        let threadId = faberProofRecord.threadId
        let aliceProofRecord = try await getProofRecord(for: aliceAgent, threadId: threadId)
        XCTAssertEqual(aliceProofRecord.state, .RequestReceived)

        let expectation = TestHelper.expectation(description: "Problem report received")
        faberAgent.agentDelegate = TestDelegate(expectation: expectation, threadId: threadId)

        _ = try await aliceAgent.proofs.declineRequest(proofRecordId: aliceProofRecord.id)
        try await TestHelper.wait(for: expectation, timeout: 5)
    }
}
