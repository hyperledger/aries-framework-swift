
import XCTest
@testable import AriesFramework
import Criollo

class InvitationUrlParserTest: XCTestCase {
    let oobUrl = "http://example.com/ssi?oob=eyJAdHlwZSI6Imh0dHBzOi8vZGlkY29tbS5vcmcvb3V0LW9mLWJhbmQvMS4xL2ludml0YXRpb24iLCJAaWQiOiI2OTIxMmEzYS1kMDY4LTRmOWQtYTJkZC00NzQxYmNhODlhZjMiLCJsYWJlbCI6IkZhYmVyIENvbGxlZ2UiLCJnb2FsX2NvZGUiOiJpc3N1ZS12YyIsImdvYWwiOiJUbyBpc3N1ZSBhIEZhYmVyIENvbGxlZ2UgR3JhZHVhdGUgY3JlZGVudGlhbCIsImhhbmRzaGFrZV9wcm90b2NvbHMiOlsiaHR0cHM6Ly9kaWRjb21tLm9yZy9kaWRleGNoYW5nZS8xLjAiLCJodHRwczovL2RpZGNvbW0ub3JnL2Nvbm5lY3Rpb25zLzEuMCJdLCJzZXJ2aWNlcyI6WyJkaWQ6c292OkxqZ3BTVDJyanNveFllZ1FEUm03RUwiXX0K"
    let invitationUrl = "https://example.com?c_i=eyJAdHlwZSI6ICJkaWQ6c292OkJ6Q2JzTlloTXJqSGlxWkRUVUFTSGc7c3BlYy9jb25uZWN0aW9ucy8xLjAvaW52aXRhdGlvbiIsICJAaWQiOiAiZmM3ODFlMDItMjA1YS00NGUzLWE5ZTQtYjU1Y2U0OTE5YmVmIiwgInNlcnZpY2VFbmRwb2ludCI6ICJodHRwczovL2RpZGNvbW0uZmFiZXIuYWdlbnQuYW5pbW8uaWQiLCAibGFiZWwiOiAiQW5pbW8gRmFiZXIgQWdlbnQiLCAicmVjaXBpZW50S2V5cyI6IFsiR0hGczFQdFRabjdmYU5LRGVnMUFzU3B6QVAyQmpVckVjZlR2bjc3SnBRTUQiXX0="

    func testPlainUrl() async throws {
        var (outOfBandInvitation, invitation) = try await InvitationUrlParser.parseUrl(oobUrl)
        XCTAssertNotNil(outOfBandInvitation)
        XCTAssertNil(invitation)
        XCTAssertEqual(outOfBandInvitation?.label, "Faber College")

        (outOfBandInvitation, invitation) = try await InvitationUrlParser.parseUrl(invitationUrl)
        XCTAssertNil(outOfBandInvitation)
        XCTAssertNotNil(invitation)
    }

    func testShortUrl() async throws {
        let server = CRHTTPServer()
        server.get("/invitation") { (req, res, next) in
            Task {
                let invitation = try ConnectionInvitationMessage.fromUrl(self.invitationUrl)
                let message = try JSONEncoder().encode(invitation)
                res.setValue("application/json", forHTTPHeaderField: "Content-type")
                res.send(String(data: message, encoding: .utf8)!)
            }
        }

        server.get("/oob") { (req, res, next) in
            Task {
                let oob = try OutOfBandInvitation.fromUrl(self.oobUrl)
                let message = try JSONEncoder().encode(oob)
                res.setValue("application/json", forHTTPHeaderField: "Content-type")
                res.send(String(data: message, encoding: .utf8)!)
            }
        }

        var serverError: NSError?
        print("starting server on port 8080")
        server.startListening(&serverError, portNumber: 8080)

        var (outOfBandInvitation, invitation) = try await InvitationUrlParser.parseUrl("http://localhost:8080/oob")
        XCTAssertNotNil(outOfBandInvitation)
        XCTAssertNil(invitation)
        XCTAssertEqual(outOfBandInvitation?.label, "Faber College")

        (outOfBandInvitation, invitation) = try await InvitationUrlParser.parseUrl("http://localhost:8080/invitation")
        XCTAssertNil(outOfBandInvitation)
        XCTAssertNotNil(invitation)

        do {
            (outOfBandInvitation, invitation) = try await InvitationUrlParser.parseUrl("http://localhost:8080/invalid")
            XCTFail("Should throw error")
        } catch {
            print("Error: \(error)")
        }
    }
}
