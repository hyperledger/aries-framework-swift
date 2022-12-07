// swiftlint:disable force_cast

import XCTest
@testable import AriesFramework

class CredentialValuesTest: XCTestCase {

    let testEncodings = [
        "address2": [
            "raw": "101 Wilson Lane",
            "encoded": "68086943237164982734333428280784300550565381723532936263016368251445461241953"
        ],
        "zip": [
            "raw": "87121",
            "encoded": "87121"
        ],
        "city": [
            "raw": "SLC",
            "encoded": "101327353979588246869873249766058188995681113722618593621043638294296500696424"
        ],
        "address1": [
            "raw": "101 Tela Lane",
            "encoded": "63690509275174663089934667471948380740244018358024875547775652380902762701972"
        ],
        "state": [
            "raw": "UT",
            "encoded": "93856629670657830351991220989031130499313559332549427637940645777813964461231"
        ],
        "Empty": [
            "raw": "",
            "encoded": "102987336249554097029535212322581322789799900648198034993379397001115665086549"
        ],
        "str True": [
            "raw": "True",
            "encoded": "27471875274925838976481193902417661171675582237244292940724984695988062543640"
        ],
        "str False": [
            "raw": "False",
            "encoded": "43710460381310391454089928988014746602980337898724813422905404670995938820350"
        ],
        "max i32": [
            "raw": "2147483647",
            "encoded": "2147483647"
        ],
        "max i32 + 1": [
            "raw": "2147483648",
            "encoded": "26221484005389514539852548961319751347124425277437769688639924217837557266135"
        ],
        "min i32": [
            "raw": "-2147483648",
            "encoded": "-2147483648"
        ],
        "min i32 - 1": [
            "raw": "-2147483649",
            "encoded": "68956915425095939579909400566452872085353864667122112803508671228696852865689"
        ],
        "str 0.0": [
            "raw": "0.0",
            "encoded": "62838607218564353630028473473939957328943626306458686867332534889076311281879"
        ],
        "chr 0": [
            "raw": "\u{0}",
            "encoded": "49846369543417741186729467304575255505141344055555831574636310663216789168157"
        ],
        "chr 1": [
            "raw": "\u{1}",
            "encoded": "34356466678672179216206944866734405838331831190171667647615530531663699592602"
        ],
        "chr 2": [
            "raw": "\u{2}",
            "encoded": "99398763056634537812744552006896172984671876672520535998211840060697129507206"
        ]
    ]

    func testEncoding() async throws {
        for (key, value) in testEncodings {
            XCTAssertTrue(CredentialValues.checkValidEncoding(raw: value["raw"]!, encoded: value["encoded"]!), "[\(key)] failed to encode correctly")
        }
    }

    func testConvertAttributes() async throws {
        let attributes = [
            CredentialPreviewAttribute(name: "address2", value: "101 Wilson Lane"),
            CredentialPreviewAttribute(name: "zip", value: "87121")
        ]
        let values = try CredentialValues.convertAttributesToValues(attributes: attributes)
        let credValues = try JSONSerialization.jsonObject(with: values.data(using: .utf8)!, options: []) as! [String: Any]
        let address2 = credValues["address2"] as! [String: String]
        XCTAssertTrue(address2["raw"] == "101 Wilson Lane")
        XCTAssertTrue(address2["encoded"] == "68086943237164982734333428280784300550565381723532936263016368251445461241953")
        let zip = credValues["zip"] as! [String: String]
        XCTAssertTrue(zip["raw"] == "87121")
        XCTAssertTrue(zip["encoded"] == "87121")
    }
}
