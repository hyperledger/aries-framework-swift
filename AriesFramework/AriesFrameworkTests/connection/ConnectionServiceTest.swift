
import XCTest
@testable import AriesFramework
import Indy

let connectionImageUrl = "https://example.com/image.png"

class ConnectionServiceTest: XCTestCase {
    var routing: Routing!
    var connectionService: ConnectionService!
    var agent: Agent!
    var config: AgentConfig!

    override func setUp() async throws {
        try await super.setUp()

        let key = try await IndyWallet.generateKey(forConfig: nil)
        config = AgentConfig(
            walletId: "wallet_id", walletKey: key!,
            genesisPath: "", poolName: "pool_id",
            mediatorConnectionsInvite: nil, label: "Default Agent",
            autoAcceptConnections: true,
            connectionImageUrl: connectionImageUrl,
            useLedgerSerivce: false
        )

        routing = Routing(
            endpoints: config.endpoints,
            verkey: "fakeVerkey",
            did: "fakeDid",
            routingKeys: [],
            mediatorId: "fakeMediatorId"
        )

        agent = Agent(
            agentConfig: config,
            agentDelegate: nil
        )
        try await agent.initialize()
        connectionService = agent.connectionService
    }

    override func tearDown() async throws {
        try await super.tearDown()
        try await agent.reset()
    }

    func testProcessInvitation() async throws {
        // It returns a connection record containing the information from the connection invitation

        let recipientKey = "key-1"
        let invitation = ConnectionInvitationMessage(
            id: "test",
            label: "test label",
            imageUrl: connectionImageUrl,
            recipientKeys: [recipientKey],
            serviceEndpoint: "https://test.com/msg"
        )

        let connection = try await connectionService.processInvitation(invitation, routing: routing)
        let connectionAlias = try await connectionService.processInvitation(invitation, routing: routing, alias: "test-alias")

        XCTAssertEqual(connection.role, ConnectionRole.Invitee)
        XCTAssertEqual(connection.state, ConnectionState.Invited)
        XCTAssertNil(connection.autoAcceptConnection)
        XCTAssertNotNil(connection.id)
        XCTAssertNotNil(connection.verkey)
        XCTAssertEqual(connection.mediatorId, "fakeMediatorId")

        let tags = connection.getTags()
        XCTAssertEqual(tags["verkey"], connection.verkey)
        XCTAssertEqual(tags["invitationKey"], recipientKey)

        XCTAssertNil(connection.alias)
        XCTAssertEqual(connectionAlias.alias, "test-alias")
        XCTAssertEqual(connection.theirLabel, "test label")
        XCTAssertEqual(connection.imageUrl, connectionImageUrl)
    }

    func testCreateRequest() async throws {
        // It returns a connection request message containing the information from the connection record

        let connection = TestHelper.getMockConnection()
        try await connectionService.connectionRepository.save(connection)

        let outboundMessage = try await connectionService.createRequest(connectionId: connection.id)
        // swiftlint:disable:next force_cast
        let message = outboundMessage.payload as! ConnectionRequestMessage

        XCTAssertEqual(outboundMessage.connection.state, ConnectionState.Requested)
        XCTAssertEqual(message.label, config.label)
        XCTAssertEqual(message.connection.did, "test-did")

        let encoder = JSONEncoder()
        XCTAssertEqual(try encoder.encode(message.connection.didDoc), try encoder.encode(connection.didDoc))
        XCTAssertEqual(message.imageUrl, connectionImageUrl)
    }
}
