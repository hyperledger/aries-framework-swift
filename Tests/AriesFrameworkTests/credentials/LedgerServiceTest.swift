import XCTest
@testable import AriesFramework
import Anoncreds

final class LedgerServiceTest: XCTestCase {
    var agent: Agent!

    override func setUp() async throws {
        try await super.setUp()
        let config = try TestHelper.getBaseConfig(name: "faber", useLedgerService: true)
        agent = Agent(agentConfig: config, agentDelegate: nil)
        try await agent.initialize()
    }

    override func tearDown() async throws {
        try await agent?.reset()
        try await super.tearDown()
    }

    func testPrepareIssuance() async throws {
        let attributes = ["name", "age"]
        let credDefId = try await TestHelper.prepareForIssuance(agent, attributes)
        print("credential definition id: \(credDefId)")

        let credDefJson = try await agent.ledgerService.getCredentialDefinition(id: credDefId)
        let credDef = try CredentialDefinition(json: credDefJson)
        print("schema id: \(credDef.schemaId())")
        print("cred def id: \(credDef.credDefId())")
    }
}
