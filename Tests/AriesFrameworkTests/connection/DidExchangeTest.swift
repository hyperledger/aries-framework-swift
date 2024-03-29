
import XCTest
@testable import AriesFramework

class DidExchangeTest: XCTestCase {
    var faberAgent: Agent!
    var aliceAgent: Agent!

    override func setUp() async throws {
        try await super.setUp()

        let faberConfig = try TestHelper.getBaseConfig(name: "faber")
        let aliceConfig = try TestHelper.getBaseConfig(name: "alice")

        class TestDelegate: AgentDelegate {
            let name: String
            init(name: String) {
                self.name = name
            }
            func onConnectionStateChanged(connectionRecord: ConnectionRecord) {
                print("\(name): connection state changed to \(connectionRecord.state)")
            }
        }
        faberAgent = Agent(agentConfig: faberConfig, agentDelegate: TestDelegate(name: "faber"))
        aliceAgent = Agent(agentConfig: aliceConfig, agentDelegate: TestDelegate(name: "alice"))

        faberAgent.setOutboundTransport(SubjectOutboundTransport(subject: aliceAgent))
        aliceAgent.setOutboundTransport(SubjectOutboundTransport(subject: faberAgent))

        try await faberAgent.initialize()
        try await aliceAgent.initialize()
    }

    override func tearDown() async throws {
        try await faberAgent.reset()
        try await aliceAgent.reset()
        try await super.tearDown()
    }

    func testOobConnection() async throws {
        let outOfBandRecord = try await faberAgent.oob.createInvitation(config: CreateOutOfBandInvitationConfig())
        let invitation = outOfBandRecord.outOfBandInvitation

        aliceAgent.agentConfig.preferredHandshakeProtocol = .DidExchange11
        let (_, connection) = try await aliceAgent.oob.receiveInvitation(invitation)
        guard let aliceFaberConnection = connection else {
            XCTFail("Connection is nil after receiving invitation from url")
            return
        }
        XCTAssertEqual(aliceFaberConnection.state, .Complete)

        guard let faberAliceConnection = await faberAgent.connectionService.findByInvitationKey(try invitation.invitationKey()!) else {
            XCTFail("Cannot find connection by invitation key")
            return
        }
        XCTAssertEqual(faberAliceConnection.state, .Complete)

        XCTAssertTrue(TestHelper.isConnectedWith(received: faberAliceConnection, connection: aliceFaberConnection))
        XCTAssertTrue(TestHelper.isConnectedWith(received: aliceFaberConnection, connection: faberAliceConnection))
    }
}
