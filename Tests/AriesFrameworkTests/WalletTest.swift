
import XCTest
@testable import AriesFramework

class WalletTest: XCTestCase {
    var agent: Agent!

    override func setUp() async throws {
        try await super.setUp()

        let config = try TestHelper.getBaseConfig(name: "alice")
        agent = Agent(agentConfig: config, agentDelegate: nil)
        try await agent.wallet.initialize()
    }

    override func tearDown() async throws {
        try await super.tearDown()
        if agent.wallet.session != nil {
            try await agent.wallet.delete()
        }
    }

    func testInitAndDelete() async throws {
        let wallet = agent.wallet!
        XCTAssertNotNil(wallet.session)

        try? await wallet.delete()
        XCTAssertNil(wallet.session)
    }

    func testIfTheDuplicateErrorIsIgnoredWhenCreatingDID() async throws {
        let (_, _) = try await agent.wallet.createDid(seed: "00000000000000000000000000000My1")
        let (_, _) = try await agent.wallet.createDid(seed: "00000000000000000000000000000My1")
    }

    func testPackUnpack() async throws {
        let json = """
          {
            "@type": "\(ConnectionInvitationMessage.type)",
            "@id": "04a2c382-999e-4de9-a1d2-9dec0b2fa5e4",
            "recipientKeys": ["recipientKeyOne", "recipientKeyTwo"],
            "serviceEndpoint": "https://example.com",
            "label": "test"
          }
        """
        let invitation = try JSONDecoder().decode(ConnectionInvitationMessage.self, from: Data(json.utf8))
        let (_, verkey) = try await agent.wallet.createDid(seed: "00000000000000000000000000000My1")
        let encryptedMessage = try await agent.wallet.pack(message: invitation, recipientKeys: [verkey], senderVerkey: verkey)
        let decryptedMessage = try await agent.wallet.unpack(encryptedMessage: encryptedMessage)
        XCTAssertEqual(decryptedMessage.senderKey, verkey)
        let decrypedInvitation = try JSONDecoder().decode(ConnectionInvitationMessage.self, from: Data(decryptedMessage.plaintextMessage.utf8))
        XCTAssertEqual(decrypedInvitation.id, invitation.id)
    }

    func testInitTwice() async throws {
        let wallet = agent.wallet!
        XCTAssertNotNil(wallet.session)

        // Try to initialize again. It will close the wallet and reopen it.
        try await wallet.initialize()
        XCTAssertNotNil(wallet.session)
    }
}
