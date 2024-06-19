
import XCTest
@testable import AriesFramework

class ConnectionlessExchangeTest: XCTestCase {
    var issuerAgent: Agent!
    var holderAgent: Agent!
    var verifierAgent: Agent!

    var credDefId: String!

    let credentialPreview = CredentialPreview.fromDictionary([
        "name": "John",
        "age": "99"
    ])

    override func setUp() async throws {
        try await super.setUp()

        var issuerConfig = try TestHelper.getBaseConfig(name: "issuer", useLedgerService: true)
        issuerConfig.autoAcceptCredential = .always
        self.issuerAgent = Agent(agentConfig: issuerConfig, agentDelegate: nil)

        var holderConfig = try TestHelper.getBaseConfig(name: "holder", useLedgerService: true)
        holderConfig.autoAcceptCredential = .always
        holderConfig.autoAcceptProof = .always
        self.holderAgent = Agent(agentConfig: holderConfig, agentDelegate: nil)

        var verifierConfig = try TestHelper.getBaseConfig(name: "verifier", useLedgerService: true)
        verifierConfig.autoAcceptProof = .always
        self.verifierAgent = Agent(agentConfig: verifierConfig, agentDelegate: nil)

        try await issuerAgent.initialize()
        try await holderAgent.initialize()
        try await verifierAgent.initialize()

        credDefId = try await TestHelper.prepareForIssuance(issuerAgent, ["name", "age"])
    }

    override func tearDown() async throws {
        try await issuerAgent?.reset()
        try await holderAgent?.reset()
        try await verifierAgent?.reset()
        try await super.tearDown()
    }

    func testConnectionlessExchange() async throws {
        self.issuerAgent.setOutboundTransport(SubjectOutboundTransport(subject: holderAgent))
        self.holderAgent.setOutboundTransport(SubjectOutboundTransport(subject: issuerAgent))

        let offerOptions = CreateOfferOptions(
            credentialDefinitionId: credDefId,
            attributes: credentialPreview.attributes,
            comment: "this is credential-offer for you")
        let (message, record) = try await issuerAgent.credentialService.createOffer(options: offerOptions)
        try await validateState(for: issuerAgent, threadId: record.threadId, state: CredentialState.OfferSent)

        let oobConfig = CreateOutOfBandInvitationConfig(
            label: "issuer-to-holder-invitation",
            alias: "issuer-to-holder-invitation",
            handshake: false,
            messages: [message],
            multiUseInvitation: false,
            autoAcceptConnection: true)
        let oobInvitation = try await issuerAgent.oob.createInvitation(config: oobConfig)

        let (oob, connection) = try await holderAgent.oob.receiveInvitation(oobInvitation.outOfBandInvitation)
        XCTAssertNotNil(connection)
        XCTAssertEqual(connection?.state, .Complete)
        XCTAssertNotNil(oob)

        try await Task.sleep(nanoseconds: UInt64(5 * SECOND))
        try await validateState(for: holderAgent, threadId: record.threadId, state: CredentialState.Done)
        try await validateState(for: issuerAgent, threadId: record.threadId, state: CredentialState.Done)

        // credential exchange done.

        self.holderAgent.setOutboundTransport(SubjectOutboundTransport(subject: verifierAgent))
        self.verifierAgent.setOutboundTransport(SubjectOutboundTransport(subject: holderAgent))

        let proofRequest = try await getProofRequest()
        let (proofRequestMessage, proofExchangeRecord) = try await verifierAgent.proofService.createRequest(proofRequest: proofRequest)
        try await validateState(for: verifierAgent, threadId: proofExchangeRecord.threadId, state: ProofState.RequestSent)

        let oobConfigForProofExchange = CreateOutOfBandInvitationConfig(
            label: "verifier-to-holder-invitation",
            alias: "verifier-to-holder-invitation",
            handshake: false,
            messages: [proofRequestMessage],
            multiUseInvitation: false,
            autoAcceptConnection: true)
        let oobInvitationForProofExchange = try await verifierAgent.oob.createInvitation(config: oobConfigForProofExchange)

        let (oobForProofExchange, connectionForProofExchange) = try await holderAgent.oob.receiveInvitation(oobInvitationForProofExchange.outOfBandInvitation)
        XCTAssertNotNil(connectionForProofExchange)
        XCTAssertEqual(connectionForProofExchange?.state, .Complete)
        XCTAssertNotNil(oobForProofExchange)

        try await Task.sleep(nanoseconds: UInt64(5 * SECOND))
        try await validateState(for: holderAgent, threadId: proofExchangeRecord.threadId, state: ProofState.Done)
        try await validateState(for: verifierAgent, threadId: proofExchangeRecord.threadId, state: ProofState.Done)
    }

    func validateState(for agent: Agent, threadId: String, state: CredentialState) async throws {
        let record = try await agent.credentialExchangeRepository.getByThreadAndConnectionId(threadId: threadId, connectionId: nil)
        XCTAssertEqual(record.state, state, "agent=\(agent.agentConfig.label)")
    }

    func validateState(for agent: Agent, threadId: String, state: ProofState) async throws {
        let record = try await agent.proofRepository.getByThreadAndConnectionId(threadId: threadId, connectionId: nil)
        XCTAssertEqual(record.state, state, "agent=\(agent.agentConfig.label)")
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
