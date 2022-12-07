
import XCTest
@testable import AriesFramework

class DIDParserTest: XCTestCase {
    let VERKEY = "8HH5gYEeNc3z7PYXmd54d4x6qAfCNrqQqEB3nS7Zfu7K"
    let DERIVED_DID_KEY = "did:key:z6MkmjY8GnV5i9YTDtPETC2uUAW6ejw3nk5mXF5yci5ab7th"
    let VALID_SECP256K1_0 = "did:key:zQ3shokFTS3brHcDQrn82RUDfCZESWL1ZdCEJwekUDPQiYBme"

    func testParse() throws {
        var did = "did:aries:did.example.com"
        XCTAssertEqual(try DIDParser.getMethodId(did: did), "did.example.com")

        did = "did:example:123456/path"
        XCTAssertEqual(try DIDParser.getMethodId(did: did), "123456")

        did = "did:example:123456?versionId=1"
        XCTAssertEqual(try DIDParser.getMethodId(did: did), "123456")

        did = "did:example:123?service=agent&relativeRef=/credentials#degree"
        XCTAssertEqual(try DIDParser.getMethodId(did: did), "123")

        did = "did:key:12345"
        XCTAssertEqual(try DIDParser.getMethod(did: did), "key")
    }

    func testDidKeyEncoding() throws {
        let did = try DIDParser.ConvertVerkeyToDidKey(verkey: VERKEY)
        XCTAssertEqual(did, DERIVED_DID_KEY)

        let verkey = try DIDParser.ConvertDidKeyToVerkey(did: did)
        XCTAssertEqual(verkey, VERKEY)

        let verkey2 = try DIDParser.ConvertFingerprintToVerkey(fingerprint: DIDParser.getMethodId(did: did))
        XCTAssertEqual(verkey2, VERKEY)

        do {
            _ = try DIDParser.ConvertDidKeyToVerkey(did: VALID_SECP256K1_0)
            XCTFail("Expected exception")
        } catch {
            // expected
        }
    }
}
