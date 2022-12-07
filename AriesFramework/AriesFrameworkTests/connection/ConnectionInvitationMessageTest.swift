
import XCTest
@testable import AriesFramework

class ConnectionInvitationMessageTest: XCTestCase {
    func testNoRoutingKey() throws {
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
        XCTAssertNotNil(invitation, "should allow routingKeys to be left out of inline invitation")
    }

    func testValidateKeys() {
        let json = """
          {
            "@type": "\(ConnectionInvitationMessage.type)",
            "@id": "04a2c382-999e-4de9-a1d2-9dec0b2fa5e4",
            "label": "test"
          }
        """
        let invitation = try? JSONDecoder().decode(ConnectionInvitationMessage.self, from: Data(json.utf8))
        XCTAssertNil(invitation, "should throw error if both did and inline keys / endpoint are missing")
    }

    func testFromUrl() throws {
        let invitationUrl =
            "https://trinsic.studio/link/?d_m=eyJsYWJlbCI6InRlc3QiLCJpbWFnZVVybCI6Imh0dHBzOi8vdHJpbnNpY2FwaWFzc2V0cy5henVyZWVkZ2UubmV0L2ZpbGVzL2IyODhkMTE3LTNjMmMtNGFjNC05MzVhLWE1MDBkODQzYzFlOV9kMGYxN2I0OS0wNWQ5LTQ4ZDAtODJlMy1jNjg3MGI4MjNjMTUucG5nIiwic2VydmljZUVuZHBvaW50IjoiaHR0cHM6Ly9hcGkucG9ydGFsLnN0cmVldGNyZWQuaWQvYWdlbnQvTVZob1VaQjlHdUl6bVJzSTNIWUNuZHpBcXVKY1ZNdFUiLCJyb3V0aW5nS2V5cyI6WyJCaFZRdEZHdGJ4NzZhMm13Y3RQVkJuZWtLaG1iMTdtUHdFMktXWlVYTDFNaSJdLCJyZWNpcGllbnRLZXlzIjpbIkcyOVF6bXBlVXN0dUVHYzlXNzlYNnV2aUhTUTR6UlV2VWFFOHpXV2VZYjduIl0sIkBpZCI6IjgxYzZiNDUzLWNkMTUtNDQwMC04MWU5LTkwZTJjM2NhY2I1NCIsIkB0eXBlIjoiZGlkOnNvdjpCekNic05ZaE1yakhpcVpEVFVBU0hnO3NwZWMvY29ubmVjdGlvbnMvMS4wL2ludml0YXRpb24ifQ%3D%3D&orig=https://trinsic.studio/url/6dd56daf-e153-40dd-b849-2b345b6853f6"

        let invitation = try ConnectionInvitationMessage.fromUrl(invitationUrl)
        XCTAssertNotNil(invitation, "should correctly convert a valid invitation url to a `ConnectionInvitationMessage` with `d_m` as parameter")
    }

    func testFromUrlCI() throws {
        let invitationUrl =
            "https://example.com?c_i=eyJAdHlwZSI6ICJkaWQ6c292OkJ6Q2JzTlloTXJqSGlxWkRUVUFTSGc7c3BlYy9jb25uZWN0aW9ucy8xLjAvaW52aXRhdGlvbiIsICJAaWQiOiAiZmM3ODFlMDItMjA1YS00NGUzLWE5ZTQtYjU1Y2U0OTE5YmVmIiwgInNlcnZpY2VFbmRwb2ludCI6ICJodHRwczovL2RpZGNvbW0uZmFiZXIuYWdlbnQuYW5pbW8uaWQiLCAibGFiZWwiOiAiQW5pbW8gRmFiZXIgQWdlbnQiLCAicmVjaXBpZW50S2V5cyI6IFsiR0hGczFQdFRabjdmYU5LRGVnMUFzU3B6QVAyQmpVckVjZlR2bjc3SnBRTUQiXX0="

        let invitation = try ConnectionInvitationMessage.fromUrl(invitationUrl)
        XCTAssertNotNil(invitation, "should correctly convert a valid invitation url to a `ConnectionInvitationMessage` with `c_i` as parameter")
    }

    func testFromUrlCINoBase64Padding() throws {
        let invitationUrl =
            "https://example.com?c_i=eyJAdHlwZSI6ICJkaWQ6c292OkJ6Q2JzTlloTXJqSGlxWkRUVUFTSGc7c3BlYy9jb25uZWN0aW9ucy8xLjAvaW52aXRhdGlvbiIsICJAaWQiOiAiZmM3ODFlMDItMjA1YS00NGUzLWE5ZTQtYjU1Y2U0OTE5YmVmIiwgInNlcnZpY2VFbmRwb2ludCI6ICJodHRwczovL2RpZGNvbW0uZmFiZXIuYWdlbnQuYW5pbW8uaWQiLCAibGFiZWwiOiAiQW5pbW8gRmFiZXIgQWdlbnQiLCAicmVjaXBpZW50S2V5cyI6IFsiR0hGczFQdFRabjdmYU5LRGVnMUFzU3B6QVAyQmpVckVjZlR2bjc3SnBRTUQiXX0"

        let invitation = try ConnectionInvitationMessage.fromUrl(invitationUrl)
        XCTAssertNotNil(invitation, "should correctly convert a valid invitation url with no base64 padding")
    }

    func testToUrl() throws {
        let invitationUrl =
            "https://example.com?c_i=eyJAdHlwZSI6ICJkaWQ6c292OkJ6Q2JzTlloTXJqSGlxWkRUVUFTSGc7c3BlYy9jb25uZWN0aW9ucy8xLjAvaW52aXRhdGlvbiIsICJAaWQiOiAiZmM3ODFlMDItMjA1YS00NGUzLWE5ZTQtYjU1Y2U0OTE5YmVmIiwgInNlcnZpY2VFbmRwb2ludCI6ICJodHRwczovL2RpZGNvbW0uZmFiZXIuYWdlbnQuYW5pbW8uaWQiLCAibGFiZWwiOiAiQW5pbW8gRmFiZXIgQWdlbnQiLCAicmVjaXBpZW50S2V5cyI6IFsiR0hGczFQdFRabjdmYU5LRGVnMUFzU3B6QVAyQmpVckVjZlR2bjc3SnBRTUQiXX0"

        let invitation = try ConnectionInvitationMessage.fromUrl(invitationUrl)
        let url = try invitation.toUrl(domain: "https://example.com")
        let invitation1 = try ConnectionInvitationMessage.fromUrl(url)
        XCTAssertEqual(invitation.label, invitation1.label)
        XCTAssertEqual(invitation.serviceEndpoint, invitation1.serviceEndpoint)
    }
}
