// swiftlint:disable force_cast

import XCTest
@testable import AriesFramework

class ConnectionlessExchangeTest: XCTestCase {
    var issuerAgent: Agent!
    var holderAgent: Agent!

    var credDefId: String!
    var faberConnection: ConnectionRecord!
    var aliceConnection: ConnectionRecord!

    let credentialPreview = CredentialPreview.fromDictionary([
        "name": "John",
        "age": "99"
    ])
    let receiveInvitationConfig = ReceiveOutOfBandInvitationConfig(
        autoAcceptConnection: true)

    override func setUp() async throws {
        try await super.setUp()

        var issuerConfig = try TestHelper.getBaseConfig(name: "issuer", useLedgerService: true)
        issuerConfig.autoAcceptCredential = .always
        issuerConfig.autoAcceptProof = .always
        self.issuerAgent = Agent(agentConfig: issuerConfig, agentDelegate: nil)

        var holderConfig = try TestHelper.getBaseConfig(name: "holder", useLedgerService: true)
        holderConfig.autoAcceptCredential = .always
        holderConfig.autoAcceptProof = .always
        self.holderAgent = Agent(agentConfig: holderConfig, agentDelegate: nil)

        self.issuerAgent.setOutboundTransport(SubjectOutboundTransport(subject: holderAgent))
        self.holderAgent.setOutboundTransport(SubjectOutboundTransport(subject: issuerAgent))

        try await issuerAgent.initialize()
        try await holderAgent.initialize()

        credDefId = try await TestHelper.prepareForIssuance(issuerAgent, ["name", "age"])
    }

    override func tearDown() async throws {
        try await issuerAgent?.reset()
        try await holderAgent?.reset()
        try await super.tearDown()
    }

    func validateState(for agent: Agent, threadId: String, state: CredentialState) async throws {
        let record = try await agent.credentialExchangeRepository.getByThreadAndConnectionId(threadId: threadId, connectionId: nil)
        XCTAssertEqual(record.state, state, "agent=\(agent.agentConfig.label)")
    }

    func validateState(for agent: Agent, threadId: String, state: ProofState) async throws {
        let record = try await agent.proofRepository.getByThreadAndConnectionId(threadId: threadId, connectionId: nil)
        XCTAssertEqual(record.state, state, "agent=\(agent.agentConfig.label)")
    }

    func testConnectionlessCredentialExchange() async throws {
        let offerOptions = CreateOfferOptions(
            connection: faberConnection,
            credentialDefinitionId: credDefId,
            attributes: credentialPreview.attributes,
            comment: "this is credential-offer for you")
        let (message, record) = try await issuerAgent.credentialService.createOffer(options: offerOptions)
        try await validateState(for: issuerAgent, threadId: record.threadId, state: CredentialState.OfferSent)

        let oobConfig = CreateOutOfBandInvitationConfig(
            label: "issuer-to-holder-invitation",
            alias: "issuer-to-holder-invitation",
            imageUrl: nil,
            goalCode: nil,
            goal: nil,
            handshake: false,
            messages: [message],
            multiUseInvitation: false,
            autoAcceptConnection: true,
            routing: nil)
        let oobInvitation = try await issuerAgent.oob.createInvitation(config: oobConfig)

        var (oob, connection) = try await holderAgent.oob.receiveInvitation(oobInvitation.outOfBandInvitation)
        XCTAssertNotNil(connection)
        XCTAssertEqual(connection?.state, .Complete) // this is a fake connection.
        XCTAssertNotNil(oob)

        (oob, connection) = try await holderAgent.oob.acceptInvitation(outOfBandId: oob.id, config: receiveInvitationConfig)
        XCTAssertNotNil(connection)
        XCTAssertNotNil(oob)
        try await validateState(for: holderAgent, threadId: record.threadId, state: CredentialState.RequestSent)

        try await Task.sleep(nanoseconds: UInt64(5 * SECOND))

        try await validateState(for: holderAgent, threadId: record.threadId, state: CredentialState.Done)
        try await validateState(for: issuerAgent, threadId: record.threadId, state: CredentialState.Done)
    }

    func validateProofExchangeRecordState(for agent: Agent, threadId: String, state: ProofState) async throws {
        let record = try await agent.proofRepository.getByThreadAndConnectionId(threadId: threadId, connectionId: nil)
        XCTAssertEqual(record.state, state, "agent=\(agent.agentConfig.label)")
    }

    // Note: this test should be run after credential exchange is done.
    func testConnectionlessProofExchange() async throws {
        let proofRequest = try await getProofRequest()
        // TODO not implemented yet.
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
}
