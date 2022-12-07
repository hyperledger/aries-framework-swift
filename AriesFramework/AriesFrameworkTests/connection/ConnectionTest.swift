
import XCTest
@testable import AriesFramework

class ConnectionTest: XCTestCase {
    var faberAgent: Agent!
    var aliceAgent: Agent!

    override func setUp() async throws {
        try await super.setUp()

        let faberConfig = try TestHelper.getBaseConfig(name: "faber")
        let aliceConfig = try TestHelper.getBaseConfig(name: "alice")

        faberAgent = Agent(agentConfig: faberConfig, agentDelegate: nil)
        aliceAgent = Agent(agentConfig: aliceConfig, agentDelegate: nil)

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

    func testMultiUseInvite() async throws {
        let message = try await faberAgent.connections.createConnection(multiUseInvitation: true)
        // swiftlint:disable:next force_cast
        let invitation = message.payload as! ConnectionInvitationMessage
        let invitationUrl = try invitation.toUrl(domain: "https://example.com")

        var aliceFaberConnection1 = try await aliceAgent.connections.receiveInvitationFromUrl(invitationUrl)
        try await Task.sleep(nanoseconds: UInt64(0.1 * SECOND))
        aliceFaberConnection1 = try await aliceAgent.connectionRepository.getById(aliceFaberConnection1.id)
        XCTAssertEqual(aliceFaberConnection1.state, .Complete)

        var aliceFaberConnection2 = try await aliceAgent.connections.receiveInvitationFromUrl(invitationUrl)
        try await Task.sleep(nanoseconds: UInt64(0.1 * SECOND))
        aliceFaberConnection2 = try await aliceAgent.connectionRepository.getById(aliceFaberConnection2.id)
        XCTAssertEqual(aliceFaberConnection2.state, .Complete)

        let faberAliceConnection1 = try await faberAgent.connectionService.getByThreadId(aliceFaberConnection1.threadId!)
        let faberAliceConnection2 = try await faberAgent.connectionService.getByThreadId(aliceFaberConnection2.threadId!)

        XCTAssertEqual(TestHelper.isConnectedWith(received: faberAliceConnection1, connection: aliceFaberConnection1), true)
        XCTAssertEqual(TestHelper.isConnectedWith(received: faberAliceConnection2, connection: aliceFaberConnection2), true)
    }
}
