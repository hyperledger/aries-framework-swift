// swiftlint:disable force_cast

import XCTest
@testable import AriesFramework

let diddoc = [
    "@context": "https://w3id.org/did/v1",
    "id": "did:sov:LjgpST2rjsoxYegQDRm7EL",
    "publicKey": [
        [
            "id": "3",
            "type": "RsaVerificationKey2018",
            "controller": "did:sov:LjgpST2rjsoxYegQDRm7EL",
            "publicKeyPem": "-----BEGIN PUBLIC X..."
        ],
        [
            "id": "did:sov:LjgpST2rjsoxYegQDRm7EL#4",
            "type": "Ed25519VerificationKey2018",
            "controller": "did:sov:LjgpST2rjsoxYegQDRm7EL",
            "publicKeyBase58": "-----BEGIN PUBLIC 9..."
        ],
        [
            "id": "6",
            "type": "Secp256k1VerificationKey2018",
            "controller": "did:sov:LjgpST2rjsoxYegQDRm7EL",
            "publicKeyHex": "-----BEGIN PUBLIC A..."
        ]
    ],
    "service": [
        [
            "id": "0",
            "type": "Mediator",
            "serviceEndpoint": "did:sov:Q4zqM7aXqm7gDQkUVLng9h"
        ],
        [
            "id": "6",
            "type": "IndyAgent",
            "serviceEndpoint": "did:sov:Q4zqM7aXqm7gDQkUVLng9h",
            "recipientKeys": ["Q4zqM7aXqm7gDQkUVLng9h"],
            "routingKeys": ["Q4zqM7aXqm7gDQkUVLng9h"],
            "priority": 5
        ],
        [
            "id": "7",
            "type": "did-communication",
            "serviceEndpoint": "https://agent.com/did-comm",
            "recipientKeys": ["DADEajsDSaksLng9h"],
            "routingKeys": ["DADEajsDSaksLng9h"],
            "priority": 10
        ]
    ],
    "authentication": [
        [
            "type": "RsaSignatureAuthentication2018",
            "publicKey": "3"
        ],
        [
            "id": "6",
            "type": "RsaVerificationKey2018",
            "controller": "did:sov:LjgpST2rjsoxYegQDRm7EL",
            "publicKeyPem": "-----BEGIN PUBLIC A..."
        ]
    ]
] as [String: Any]

class DidDocTest: XCTestCase {
    let decoder = JSONDecoder()

    func testJsonCoding() throws {
        let diddocJson = try JSONSerialization.data(withJSONObject: diddoc, options: [])
        let didDoc = try decoder.decode(DidDoc.self, from: diddocJson)

        XCTAssertEqual(didDoc.publicKey.count, (diddoc["publicKey"] as! [Any]).count)
        XCTAssertEqual(didDoc.service.count, (diddoc["service"] as! [Any]).count)
        XCTAssertEqual(didDoc.authentication.count, (diddoc["authentication"] as! [Any]).count)

        XCTAssertEqual(didDoc.id, diddoc["id"] as? String)
        XCTAssertEqual(didDoc.context, diddoc["@context"] as? String)

        XCTAssertTrue(didDoc.publicKey[0] is RsaSig2018)
        XCTAssertTrue(didDoc.publicKey[1] is Ed25119Sig2018)
        XCTAssertTrue(didDoc.publicKey[2] is EddsaSaSigSecp256k1)

        if case .didDocument = didDoc.service[0] {} else {
            XCTFail("service 0 should be DidDocumentService")
        }
        if case .indyAgent = didDoc.service[1] {} else {
            XCTFail("service 2 should be IndyAgentService")
        }
        if case .didComm = didDoc.service[2] {} else {
            XCTFail("service 1 should be DidCommService")
        }

        if case .referenced = didDoc.authentication[0] {} else {
            XCTFail("authentication 0 should be ReferencedAuthentication")
        }
        if case .embedded = didDoc.authentication[1] {} else {
            XCTFail("authentication 1 should be EmbeddedAuthentication")
        }

        let encoder = JSONEncoder()
        let data = try encoder.encode(didDoc)
        let clone = try decoder.decode(DidDoc.self, from: data)
        XCTAssertEqual(clone.id, "did:sov:LjgpST2rjsoxYegQDRm7EL")
        XCTAssertEqual(clone.context, "https://w3id.org/did/v1")
        XCTAssertEqual(clone.publicKey.count, 3)
        XCTAssertEqual(clone.service.count, 3)
        XCTAssertEqual(clone.authentication.count, 2)

        XCTAssertEqual(clone.publicKey[0].id, "3")
        XCTAssertEqual(clone.publicKey[0].type, "RsaVerificationKey2018")
        XCTAssertEqual(clone.publicKey[0].controller, "did:sov:LjgpST2rjsoxYegQDRm7EL")
        XCTAssertEqual(clone.publicKey[0].value, "-----BEGIN PUBLIC X...")

        XCTAssertEqual(clone.publicKey[1].value, "-----BEGIN PUBLIC 9...")
        XCTAssertEqual(clone.publicKey[2].value, "-----BEGIN PUBLIC A...")

        if case .didDocument(let doc) = clone.service[0] {
            XCTAssertEqual(doc.id, "0")
            XCTAssertEqual(doc.type, "Mediator")
            XCTAssertEqual(doc.serviceEndpoint, "did:sov:Q4zqM7aXqm7gDQkUVLng9h")
        } else {
            XCTFail("service 0 should be DidDocumentService")
        }
        if case .indyAgent(let agent) = clone.service[1] {
            XCTAssertEqual(agent.id, "6")
            XCTAssertEqual(agent.type, "IndyAgent")
            XCTAssertEqual(agent.serviceEndpoint, "did:sov:Q4zqM7aXqm7gDQkUVLng9h")
            XCTAssertEqual(agent.recipientKeys, ["Q4zqM7aXqm7gDQkUVLng9h"])
            XCTAssertEqual(agent.routingKeys, ["Q4zqM7aXqm7gDQkUVLng9h"])
            XCTAssertEqual(agent.priority, 5)
        } else {
            XCTFail("service 1 should be IndyAgentService")
        }
        if case .didComm(let comm) = clone.service[2] {
            XCTAssertEqual(comm.id, "7")
            XCTAssertEqual(comm.type, "did-communication")
            XCTAssertEqual(comm.serviceEndpoint, "https://agent.com/did-comm")
            XCTAssertEqual(comm.recipientKeys, ["DADEajsDSaksLng9h"])
            XCTAssertEqual(comm.routingKeys, ["DADEajsDSaksLng9h"])
            XCTAssertEqual(comm.priority, 10)
        } else {
            XCTFail("service 2 should be DidCommService")
        }
    }

    func testGetPublicKey() throws {
        let diddocJson = try JSONSerialization.data(withJSONObject: diddoc, options: [])
        let didDoc = try decoder.decode(DidDoc.self, from: diddocJson)

        let publicKey = didDoc.publicKey(id: "3")
        XCTAssertEqual(publicKey?.id, "3")
    }

    func testGetServicesByType() throws {
        let diddocJson = try JSONSerialization.data(withJSONObject: diddoc, options: [])
        let didDoc = try decoder.decode(DidDoc.self, from: diddocJson)

        let services = didDoc.servicesByType(type: IndyAgentService.type)
        XCTAssertEqual(services.count, 1)
        XCTAssertEqual(services[0].type, "IndyAgent")
    }

    func testGetDidCommServices() throws {
        let diddocJson = try JSONSerialization.data(withJSONObject: diddoc, options: [])
        let didDoc = try decoder.decode(DidDoc.self, from: diddocJson)

        let services = didDoc.didCommServices()
        XCTAssertEqual(services.count, 2)
        XCTAssertEqual(services[0].type, DidCommService.type)
        XCTAssertEqual(services[1].type, IndyAgentService.type)
    }
}
