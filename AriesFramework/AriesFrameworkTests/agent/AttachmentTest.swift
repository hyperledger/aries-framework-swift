// swiftlint:disable force_try
import XCTest
@testable import AriesFramework

class AttachmentTest: XCTestCase {
    func testDecodeAttachment() {
        let json: String = """
        {
            "@id": "ceffce22-6471-43e4-8945-b604091981c9",
            "description": "A small picture of a cat",
            "filename": "cat.png",
            "mime-type": "text/plain",
            "lastmod_time": "2001-01-01T00:00:00Z",
            "byte_count": 9200,
            "data": {
                "base64": "eyJIZWxsbyI6IndvcmxkIn0="
            }
        }
        """

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let attachment = try! decoder.decode(Attachment.self, from: json.data(using: .utf8)!)
        XCTAssertEqual(attachment.id, "ceffce22-6471-43e4-8945-b604091981c9")
        XCTAssertEqual(attachment.description, "A small picture of a cat")
        XCTAssertEqual(attachment.filename, "cat.png")
        XCTAssertEqual(attachment.mimetype, "text/plain")
        XCTAssertEqual(attachment.lastModified, Date(timeIntervalSinceReferenceDate: 0))
        XCTAssertEqual(attachment.byteCount, 9200)
        XCTAssertEqual(attachment.data.base64, "eyJIZWxsbyI6IndvcmxkIn0=")

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let encoded = try! encoder.encode(attachment)
        let decoded = try! decoder.decode(Attachment.self, from: encoded)
        XCTAssertEqual(attachment.id, decoded.id)
        XCTAssertEqual(attachment.description, decoded.description)
        XCTAssertEqual(attachment.filename, decoded.filename)
        XCTAssertEqual(attachment.mimetype, decoded.mimetype)
        XCTAssertEqual(attachment.lastModified, decoded.lastModified)
        XCTAssertEqual(attachment.byteCount, decoded.byteCount)
        XCTAssertEqual(attachment.data.base64, decoded.data.base64)
    }

    func testAddJws() {
        let jwsA = JwsGeneralFormat(
            header: ["kid": "did:key:z6MkfD6ccYE22Y9pHKtixeczk92MmMi2oJCP6gmNooZVKB9A"],
            signature: "OsDP4FM8792J9JlessA9IXv4YUYjIGcIAnPPrEJmgxYomMwDoH-h2DMAF5YF2VtsHHyhGN_0HryDjWSEAZdYBQ",
            protected: "eyJhbGciOiJFZERTQSIsImp3ayI6eyJrdHkiOiJPS1AiLCJjcnYiOiJFZDI1NTE5IiwieCI6IkN6cmtiNjQ1MzdrVUVGRkN5SXI4STgxUWJJRGk2MnNrbU41Rm41LU1zVkUifX0"
        )
        let jwsB = JwsGeneralFormat(
            header: ["kid": "did:key:z6MkvBpZTRb7tjuUF5AkmhG1JDV928hZbg5KAQJcogvhz9ax"],
            signature: "eA3MPRpSTt5NR8EZkDNb849E9qfrlUm8-StWPA4kMp-qcH7oEc2-1En4fgpz_IWinEbVxCLbmKhWNyaTAuHNAg",
            protected: "eyJhbGciOiJFZERTQSIsImtpZCI6ImRpZDprZXk6ejZNa3ZCcFpUUmI3dGp1VUY1QWttaEcxSkRWOTI4aFpiZzVLQVFKY29ndmh6OWF4IiwiandrIjp7Imt0eSI6Ik9LUCIsImNydiI6IkVkMjU1MTkiLCJ4IjoiNmNaMmJaS21LaVVpRjlNTEtDVjhJSVlJRXNPTEhzSkc1cUJKOVNyUVlCayIsImtpZCI6ImRpZDprZXk6ejZNa3ZCcFpUUmI3dGp1VUY1QWttaEcxSkRWOTI4aFpiZzVLQVFKY29ndmh6OWF4In19"
        )

        var attachment = Attachment(id: "some-uuid", data: AttachmentData(base64: "eyJIZWxsbyI6IndvcmxkIn0="))
        attachment.addJws(jwsA)
        if case .general(let jws) = attachment.data.jws {
            XCTAssertEqual(jws.header?["kid"], "did:key:z6MkfD6ccYE22Y9pHKtixeczk92MmMi2oJCP6gmNooZVKB9A")
        } else {
            XCTFail("Expected Jws.general")
        }

        attachment.addJws(jwsB)
        if case .flattened(let jws) = attachment.data.jws {
            XCTAssertEqual(jws.signatures.count, 2)
            XCTAssertEqual(jws.signatures[0].header?["kid"], "did:key:z6MkfD6ccYE22Y9pHKtixeczk92MmMi2oJCP6gmNooZVKB9A")
            XCTAssertEqual(jws.signatures[1].header?["kid"], "did:key:z6MkvBpZTRb7tjuUF5AkmhG1JDV928hZbg5KAQJcogvhz9ax")
        } else {
            XCTFail("Expected Jws.flattened")
        }
    }
}
