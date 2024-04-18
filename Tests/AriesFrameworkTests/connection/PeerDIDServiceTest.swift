
import XCTest
@testable import AriesFramework

class PeerDIDServiceTest: XCTestCase {
    var agent: Agent!
    let verkey = "3uhKmLCRYfe5YWDsgBC4VNTKk3RbnFCzgjVH3zmSKHWa"

    override func setUp() async throws {
        try await super.setUp()
        let config = try TestHelper.getBaseConfig(name: "alice")
        agent = Agent(agentConfig: config, agentDelegate: nil)
        try await agent.initialize()
    }

    override func tearDown() async throws {
        try await agent.reset()
        try await super.tearDown()
    }

    func testPeerDIDwithLegacyService() async throws {
        let peerDID = try await agent.peerDIDService.createPeerDID(verkey: verkey)
        try parsePeerDID(peerDID)
    }

    func testPeerDIDwithDidCommV2Service() async throws {
        let peerDID = try await agent.peerDIDService.createPeerDID(verkey: verkey, useLegacyService: false)
        try parsePeerDID(peerDID)
    }

    func parsePeerDID(_ peerDID: String) throws {
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
        XCTAssertEqual(didCommService.serviceEndpoint, agent.agentConfig.endpoints[0])
    }
}
