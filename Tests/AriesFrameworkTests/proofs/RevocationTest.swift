import XCTest
@testable import AriesFramework

class RevocationTest: XCTestCase {
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

    override func setUp() async throws {
        try await super.setUp()

        (faberAgent, aliceAgent, faberConnection, aliceConnection) = try await TestHelper.setupCredentialTests()
        credDefId = try await prepareForRevocation()
    }

    override func tearDown() async throws {
        try await faberAgent?.reset()
        try await aliceAgent?.reset()
        try await super.tearDown()
    }

    func prepareForRevocation() async throws -> String {
        print("Preparing for revocation test")
        let agent = faberAgent!
        guard let didInfo = agent.wallet.publicDid else {
            throw AriesFrameworkError.frameworkError("Faber has no public DID.")
        }
        let schemaId = try await agent.ledgerService.registerSchema(did: didInfo,
            schemaTemplate: SchemaTemplate(name: "schema-\(UUID().uuidString)", version: "1.0", attributes: ["name", "sex", "age"]))
        try await Task.sleep(nanoseconds: UInt64(0.1 * SECOND))
        let (schema, seqNo) = try await agent.ledgerService.getSchema(schemaId: schemaId)
        print("Registering credential definition")
        let credDefId = try await agent.ledgerService.registerCredentialDefinition(did: didInfo,
            credentialDefinitionTemplate: CredentialDefinitionTemplate(schema: schema, tag: "default", supportRevocation: true, seqNo: seqNo))
        _ = try await agent.ledgerService.registerRevocationRegistryDefinition(
            did: didInfo,
            revRegDefTemplate: RevocationRegistryDefinitionTemplate(credDefId: credDefId, tag: "default", maxCredNum: 100))

        return credDefId
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
        print("Issuing credential...")
        aliceAgent.agentConfig.autoAcceptCredential = .always
        faberAgent.agentConfig.autoAcceptCredential = .always

        var faberCredentialRecord = try await faberAgent.credentials.offerCredential(
            options: CreateOfferOptions(
                connection: faberConnection,
                credentialDefinitionId: credDefId,
                attributes: credentialPreview.attributes,
                comment: "Offer to Alice"))
        try await Task.sleep(nanoseconds: UInt64(2 * SECOND)) // Need enough time to finish exchange a credential.

        let threadId = faberCredentialRecord.threadId
        let aliceCredentialRecord = try await getCredentialRecord(for: aliceAgent, threadId: threadId)
        faberCredentialRecord = try await getCredentialRecord(for: faberAgent, threadId: threadId)

        XCTAssertEqual(aliceCredentialRecord.state, .Done)
        XCTAssertEqual(faberCredentialRecord.state, .Done)
        print("Credential issued")
    }

    func revokeCredential() async throws {
        print("Revoking credential")
        guard let didInfo = faberAgent.wallet.publicDid else {
            throw AriesFrameworkError.frameworkError("Faber has no public DID.")
        }
        try await faberAgent.ledgerService.revokeCredential(did: didInfo, credDefId: credDefId, revocationIndex: 1)
        print("Credential revoked")
    }

    func getProofRequest() async throws -> ProofRequest {
        let attributes = ["name": ProofAttributeInfo(
            name: "name", names: nil, nonRevoked: nil,
            restrictions: [AttributeFilter(credentialDefinitionId: credDefId)])]
        let predicates = ["age": ProofPredicateInfo(
            name: "age", nonRevoked: nil, predicateType: .GreaterThanOrEqualTo, predicateValue: 50,
            restrictions: [AttributeFilter(credentialDefinitionId: credDefId)])]

        let nonce = try ProofService.generateProofRequestNonce()
        return ProofRequest(nonce: nonce, requestedAttributes: attributes, requestedPredicates: predicates, nonRevoked: RevocationInterval(from: nil, to: Int(Date().timeIntervalSince1970)))
    }

    func testProofRequestWithNonRevoked() async throws {
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

    func testVerifyAfterRevocation() async throws {
        aliceAgent.agentConfig.ignoreRevocationCheck = true

        try await issueCredential()
        try await revokeCredential()

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
        XCTAssertEqual(faberProofRecord.isVerified, false)
    }
}
