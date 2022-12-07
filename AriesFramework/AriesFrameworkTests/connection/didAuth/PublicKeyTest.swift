// swiftlint:disable force_cast

import XCTest
@testable import AriesFramework

class PublicKeyTest: XCTestCase {
    let publicKeysJson = [
        [
            "valueKey": "publicKeyPem",
            "json": [
                "id": "3",
                "type": "RsaVerificationKey2018",
                "controller": "did:sov:LjgpST2rjsoxYegQDRm7EL",
                "publicKeyPem": "-----BEGIN PUBLIC X..."
            ]
        ],
        [
            "valueKey": "publicKeyBase58",
            "json": [
                "id": "4",
                "type": "Ed25519VerificationKey2018",
                "controller": "did:sov:LjgpST2rjsoxYegQDRm7EL",
                "publicKeyBase58": "-----BEGIN PUBLIC X..."
            ]
        ],
        [
            "valueKey": "publicKeyHex",
            "json": [
                "id": "did:sov:LjgpST2rjsoxYegQDRm7EL#5",
                "type": "Secp256k1VerificationKey2018",
                "controller": "did:sov:LjgpST2rjsoxYegQDRm7EL",
                "publicKeyHex": "-----BEGIN PUBLIC X..."
            ]
        ]
    ]

    func decode(data: Data) throws -> Any? {
        let decoder = JSONDecoder()
        if let pubkey = try? decoder.decode(RsaSig2018.self, from: data) {
            return pubkey
        }
        if let pubkey = try? decoder.decode(Ed25119Sig2018.self, from: data) {
            return pubkey
        }
        if let pubkey = try? decoder.decode(EddsaSaSigSecp256k1.self, from: data) {
            return pubkey
        }
        return nil
    }

    func encode(pubKey: PublicKey) throws -> Data? {
        let encoder = JSONEncoder()
        switch pubKey {
        case let rsa as RsaSig2018:
            return try encoder.encode(rsa)
        case let ed25519 as Ed25119Sig2018:
            return try encoder.encode(ed25519)
        case let eddsa as EddsaSaSigSecp256k1:
            return try encoder.encode(eddsa)
        default:
            return nil
        }
    }

    func testPublicKeyCoding() async throws {
        for item in publicKeysJson {
            let pubKeyValueKey = item["valueKey"] as! String
            let pubKeyJson = item["json"] as! [String: Any]
            let pubKeyData = try JSONSerialization.data(withJSONObject: pubKeyJson, options: [])

            let pubKey = try decode(data: pubKeyData) as! PublicKey
            XCTAssertEqual(pubKey.id, pubKeyJson["id"] as? String)
            XCTAssertEqual(pubKey.type, pubKeyJson["type"] as? String)
            XCTAssertEqual(pubKey.controller, pubKeyJson["controller"] as? String)
            XCTAssertEqual(pubKey.value, pubKeyJson[pubKeyValueKey] as? String)

            let data = try encode(pubKey: pubKey)!
            let clone = try decode(data: data) as! PublicKey
            XCTAssertEqual(pubKey.id, clone.id)
            XCTAssertEqual(pubKey.type, clone.type)
            XCTAssertEqual(pubKey.controller, clone.controller)
            XCTAssertEqual(pubKey.value, clone.value)
        }
    }

    func testPublicKeyArray() async throws {
        let pubKeyArray = publicKeysJson.map { $0["json"] as! [String: Any] }
        let pubKeyArrayJson = try JSONSerialization.data(withJSONObject: pubKeyArray, options: [])
        let decoder = JSONDecoder()
        let parser = try decoder.decode(PubkeyParser.self, from: pubKeyArrayJson)
        XCTAssertEqual(parser.pubkeys.count, 3)
        if parser.pubkeys.count == 3 {
            XCTAssertEqual(parser.pubkeys[0].id, "3")
            XCTAssertEqual(parser.pubkeys[1].id, "4")
            XCTAssertEqual(parser.pubkeys[2].id, "did:sov:LjgpST2rjsoxYegQDRm7EL#5")
        }
    }

    func testPublicKeyPem() async throws {
        let json = """
            {"id": "3",
            "type": "RsaVerificationKey2018",
            "controller": "did:sov:LjgpST2rjsoxYegQDRm7EL",
            "publicKeyPem": "-----BEGIN PUBLIC X..."}
        """
        let decoder = JSONDecoder()
        let pubKey = try decoder.decode(RsaSig2018.self, from: Data(json.utf8))
        XCTAssertEqual(pubKey.id, "3")
        XCTAssertEqual(pubKey.type, "RsaVerificationKey2018")
        XCTAssertEqual(pubKey.controller, "did:sov:LjgpST2rjsoxYegQDRm7EL")
        XCTAssertEqual(pubKey.value, "-----BEGIN PUBLIC X...")

        let encoder = JSONEncoder()
        let data = try encoder.encode(pubKey)
        let clone = try decoder.decode(RsaSig2018.self, from: data)
        XCTAssertEqual(clone.id, "3")
        XCTAssertEqual(clone.type, "RsaVerificationKey2018")
        XCTAssertEqual(clone.controller, "did:sov:LjgpST2rjsoxYegQDRm7EL")
        XCTAssertEqual(clone.value, "-----BEGIN PUBLIC X...")
    }
}
