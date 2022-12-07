
import XCTest
@testable import AriesFramework

class SignatureDecoratorTest: XCTestCase {
    let data = """
    {"did":"did","did_doc":{"@context":"https://w3id.org/did/v1","service":[{"id":"did:example:123456789abcdefghi#did-communication","type":"did-communication","priority":0,"recipientKeys":["someVerkey"],"routingKeys":[],"serviceEndpoint":"https://agent.example.com/"}]}}
    """

    let signedData = SignatureDecorator(
        signatureType: "https://didcomm.org/signature/1.0/ed25519Sha512_single",
        signatureData: "AAAAAAAAAAB7ImRpZCI6ImRpZCIsImRpZF9kb2MiOnsiQGNvbnRleHQiOiJodHRwczovL3czaWQub3JnL2RpZC92MSIsInNlcnZpY2UiOlt7ImlkIjoiZGlkOmV4YW1wbGU6MTIzNDU2Nzg5YWJjZGVmZ2hpI2RpZC1jb21tdW5pY2F0aW9uIiwidHlwZSI6ImRpZC1jb21tdW5pY2F0aW9uIiwicHJpb3JpdHkiOjAsInJlY2lwaWVudEtleXMiOlsic29tZVZlcmtleSJdLCJyb3V0aW5nS2V5cyI6W10sInNlcnZpY2VFbmRwb2ludCI6Imh0dHBzOi8vYWdlbnQuZXhhbXBsZS5jb20vIn1dfX0",
        signer: "GjZWsBLgZCR18aL468JAT7w9CZRiBnpxUPPgyQxh4voa",
        signature: "zOSmKNCHKqOJGDJ6OlfUXTPJiirEAXrFn1kPiFDZfvG5hNTBKhsSzqAvlg44apgWBu7O57vGWZsXBF2BWZ5JAw")

    var agent: Agent!

    override func setUp() async throws {
        try await super.setUp()

        let config = try TestHelper.getBaseConfig(name: "alice")
        agent = Agent(agentConfig: config, agentDelegate: nil)
        try await agent.wallet.initialize()
    }

    override func tearDown() async throws {
        try await super.tearDown()
        if agent.wallet.handle != nil {
            try await agent.wallet.delete()
        }
    }

    func testSignData() async throws {
        let seed1 = "00000000000000000000000000000My1"
        let (_, verkey) = try await agent.wallet.createDid(seed: seed1)

        let signedData1 = try await SignatureDecorator.signData(data: data.data(using: .utf8)!, wallet: agent.wallet, verkey: verkey)
        XCTAssertEqual(signedData1.signatureType, signedData.signatureType)
        XCTAssertEqual(signedData1.signatureData, signedData.signatureData)
        XCTAssertEqual(signedData1.signer, signedData.signer)
        XCTAssertEqual(signedData1.signature, signedData.signature)
    }

    func testUnpack() async throws {
        let unpackedData: Data = try await signedData.unpackData()
        let unpacked = String(data: unpackedData, encoding: .utf8)!
        XCTAssertEqual(unpacked, data)
    }
}
