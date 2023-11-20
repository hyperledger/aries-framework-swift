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
        credDefId = try await prepareForIssuance()
    }

    override func tearDown() async throws {
        try await faberAgent?.reset()
        try await aliceAgent?.reset()
        try await super.tearDown()
    }

    func prepareForRevocation() async throws -> String {
        logger.debug("Preparing for revocation test")
        let agent = faberAgent
        guard let didInfo = agent.wallet.publicDid else {
            throw AriesFrameworkError.frameworkError("Agent has no public DID.")
        }
        let schemaId = try await agent.ledgerService.registerSchema(did: didInfo,
            schemaTemplate: SchemaTemplate(name: "schema-\(UUID().uuidString)", version: "1.0", attributes: ["name", "sex", "age"]))
        try await Task.sleep(nanoseconds: UInt64(0.1 * SECOND))
        let (schema, seqNo) = try await agent.ledgerService.getSchema(schemaId: schemaId)
        logger.debug("Registering credential definition")
        let credDefId = try await agent.ledgerService.registerCredentialDefinition(did: didInfo,
            credentialDefinitionTemplate: CredentialDefinitionTemplate(schema: schema, tag: "default", supportRevocation: true, seqNo: seqNo))
        let _ = try await agent.ledgerService.registerRevocationRegistryDefinition(did: didInfo,
            revocationRegistryTemplate: RevocationRegistryDefinitionTemplate(credDefId: credDefId, tag: "default", maxCredNum: 100))

        return credDefId
    }

    func testPrepareForRevocation() async throws {
        let credDefId = try await prepareForRevocation()
        print(credDefId)
    }
}