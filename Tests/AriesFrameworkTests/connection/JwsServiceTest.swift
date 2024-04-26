import XCTest
@testable import AriesFramework

class JwsServiceTest: XCTestCase {
    var agent: Agent!
    let seed = "00000000000000000000000000000My2"
    let verkey = "kqa2HyagzfMAq42H5f9u3UMwnSBPQx2QfrSyXbUPxMn"
    let payload = "hello".data(using: .utf8)!

    override func setUp() async throws {
        try await super.setUp()
        let config = try TestHelper.getBaseConfig(name: "alice")
        agent = Agent(agentConfig: config, agentDelegate: nil)
        try await agent.initialize()

        let (_, newKey) = try await agent.wallet.createDid(seed: seed)
        XCTAssertEqual(newKey, verkey)
    }

    override func tearDown() async throws {
        try await agent.reset()
        try await super.tearDown()
    }

    func testCreateAndVerify() async throws {
        let jws = try await agent.jwsService.createJws(payload: payload, verkey: verkey)
        XCTAssertEqual("did:key:z6MkfD6ccYE22Y9pHKtixeczk92MmMi2oJCP6gmNooZVKB9A", jws.header?["kid"])
        let protectedJson = Data(base64Encoded: jws.protected.base64urlToBase64())!
        let protected = try JSONSerialization.jsonObject(with: protectedJson) as? [String: Any]
        XCTAssertEqual("EdDSA", protected?["alg"] as? String)
        XCTAssertNotNil(protected?["jwk"])

        let (isValid, signer) = try agent.jwsService.verifyJws(jws: .general(jws), payload: payload)
        XCTAssertTrue(isValid)
        XCTAssertEqual(signer, verkey)
    }

    func testFlattenedJws() async throws {
        let jws = try await agent.jwsService.createJws(payload: payload, verkey: verkey)
        let list: Jws = .flattened(JwsFlattenedFormat(signatures: [jws]))

        let (isValid, signer) = try agent.jwsService.verifyJws(jws: list, payload: payload)
        XCTAssertTrue(isValid)
        XCTAssertEqual(signer, verkey)
    }

    func testVerifyFail() async throws {
        let wrongPayload = "world".data(using: .utf8)!
        let jws = try await agent.jwsService.createJws(payload: payload, verkey: verkey)
        let (isValid, signer) = try agent.jwsService.verifyJws(jws: .general(jws), payload: wrongPayload)
        XCTAssertFalse(isValid)
        XCTAssertEqual(signer, verkey)
    }
}
