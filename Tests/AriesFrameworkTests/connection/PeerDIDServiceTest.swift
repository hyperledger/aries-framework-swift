
import XCTest
@testable import AriesFramework

class PeerDIDServiceTest: XCTestCase {
    var agent: Agent!
    let verkey = "3uhKmLCRYfe5YWDsgBC4VNTKk3RbnFCzgjVH3zmSKHWa"

    override func tearDown() async throws {
        try await agent.reset()
        try await super.tearDown()
    }

    func testPeerDIDnumAlgo0() async throws {
        let config = try TestHelper.getBaseConfig(name: "alice")
        agent = Agent(agentConfig: config, agentDelegate: nil)
        try await agent.initialize()

        let peerDID = try await agent.peerDIDService.createPeerDID(verkey: verkey)
        XCTAssertTrue(peerDID.starts(with: "did:peer:0"))
        let key1 = peerDID.dropFirst(10)

        let didKey = try DIDParser.ConvertVerkeyToDidKey(verkey: verkey)
        XCTAssertTrue(didKey.starts(with: "did:key:"))
        let key2 = didKey.dropFirst(8)

        XCTAssertEqual(key1, key2)

        let didDoc = try agent.peerDIDService.parsePeerDID(peerDID)
        XCTAssertEqual(didDoc.id, peerDID)
        XCTAssertEqual(didDoc.publicKey.count, 1)
        XCTAssertEqual(didDoc.service.count, 1)
        XCTAssertEqual(didDoc.authentication.count, 1)
        XCTAssertEqual(didDoc.publicKey[0].value, verkey)
    }

    func testPeerDIDnumAlgo2() async throws {
        var config = try TestHelper.getBaseConfig(name: "alice")
        config.mediatorConnectionsInvite = "http://mediator.example.com/connections"
        config.useMediator = false
        agent = Agent(agentConfig: config, agentDelegate: nil)
        try await agent.initialize()

        let peerDID = try await agent.peerDIDService.createPeerDID(verkey: verkey)
        XCTAssertTrue(peerDID.starts(with: "did:peer:2"))

        let didDoc = try agent.peerDIDService.parsePeerDID(peerDID)
        XCTAssertEqual(didDoc.id, peerDID)
        XCTAssertEqual(didDoc.publicKey.count, 1)
        XCTAssertEqual(didDoc.service.count, 1)
        XCTAssertEqual(didDoc.authentication.count, 1)
        XCTAssertEqual(didDoc.publicKey[0].value, verkey)

        guard let service = didDoc.service.first else {
            XCTFail("No service found")
            return
        }
        guard case let .didComm(didCommService) = service else {
            XCTFail("Service is not a DIDComm service")
            return
        }
        XCTAssertEqual(didCommService.recipientKeys.count, 1)
        XCTAssertEqual(didCommService.recipientKeys[0], verkey)
        XCTAssertEqual(didCommService.routingKeys?.count, 0)
        // XCTAssertEqual(didCommService.serviceEndpoint, config.mediatorConnectionsInvite)
        // The above should be true, but the service endpoint is not set in the test with config.useMediator = false
        XCTAssertEqual(didCommService.serviceEndpoint, agent.agentConfig.endpoints[0])
    }
}
