
import XCTest
@testable import AriesFramework

class OutOfBandInvitationTest: XCTestCase {
    func testToUrl() throws {
        let domain = "https://example.com/ssi"
        let jsonObject = [
            "@type": "https://didcomm.org/out-of-band/1.1/invitation",
            "services": ["did:sov:LjgpST2rjsoxYegQDRm7EL"],
            "@id": "69212a3a-d068-4f9d-a2dd-4741bca89af3",
            "label": "Faber College",
            "goal_code": "issue-vc",
            "goal": "To issue a Faber College Graduate credential",
            "handshake_protocols": ["https://didcomm.org/didexchange/1.0", "https://didcomm.org/connections/1.0"]
        ] as [String: Any]
        let json = try JSONSerialization.data(withJSONObject: jsonObject, options: [])
        let invitation = try JSONDecoder().decode(OutOfBandInvitation.self, from: json)
        let invitationUrl = try invitation.toUrl(domain: domain)

        let decodedInvitation = try OutOfBandInvitation.fromUrl(invitationUrl)
        XCTAssertEqual(invitation.id, decodedInvitation.id)
        XCTAssertEqual(invitation.type, decodedInvitation.type)
        XCTAssertEqual(invitation.label, decodedInvitation.label)
        XCTAssertEqual(invitation.goalCode, decodedInvitation.goalCode)
        XCTAssertEqual(invitation.goal, decodedInvitation.goal)
        XCTAssertEqual(invitation.handshakeProtocols, decodedInvitation.handshakeProtocols)
    }

    func testFromUrl() throws {
        let invitationUrl = "http://example.com/ssi?oob=eyJAdHlwZSI6Imh0dHBzOi8vZGlkY29tbS5vcmcvb3V0LW9mLWJhbmQvMS4xL2ludml0YXRpb24iLCJAaWQiOiI2OTIxMmEzYS1kMDY4LTRmOWQtYTJkZC00NzQxYmNhODlhZjMiLCJsYWJlbCI6IkZhYmVyIENvbGxlZ2UiLCJnb2FsX2NvZGUiOiJpc3N1ZS12YyIsImdvYWwiOiJUbyBpc3N1ZSBhIEZhYmVyIENvbGxlZ2UgR3JhZHVhdGUgY3JlZGVudGlhbCIsImhhbmRzaGFrZV9wcm90b2NvbHMiOlsiaHR0cHM6Ly9kaWRjb21tLm9yZy9kaWRleGNoYW5nZS8xLjAiLCJodHRwczovL2RpZGNvbW0ub3JnL2Nvbm5lY3Rpb25zLzEuMCJdLCJzZXJ2aWNlcyI6WyJkaWQ6c292OkxqZ3BTVDJyanNveFllZ1FEUm03RUwiXX0K"
        let invitation = try OutOfBandInvitation.fromUrl(invitationUrl)

        XCTAssertEqual(invitation.id, "69212a3a-d068-4f9d-a2dd-4741bca89af3")
        XCTAssertEqual(invitation.type, "https://didcomm.org/out-of-band/1.1/invitation")
        XCTAssertEqual(invitation.label, "Faber College")
        XCTAssertEqual(invitation.goalCode, "issue-vc")
        XCTAssertEqual(invitation.goal, "To issue a Faber College Graduate credential")
        XCTAssertEqual(invitation.handshakeProtocols, [HandshakeProtocol.DidExchange, HandshakeProtocol.Connections])
        if case .did(let did) = invitation.services[0] {
            XCTAssertEqual(did, "did:sov:LjgpST2rjsoxYegQDRm7EL")
        } else {
            XCTFail("Expected did service")
        }
    }

    func testFromJson() throws {
        let json: String = """
        {
            "@type": "https://didcomm.org/out-of-band/1.1/invitation",
            "@id": "69212a3a-d068-4f9d-a2dd-4741bca89af3",
            "label": "Faber College",
            "goal_code": "issue-vc",
            "goal": "To issue a Faber College Graduate credential",
            "handshake_protocols": ["https://didcomm.org/didexchange/1.0", "https://didcomm.org/connections/1.0"],
            "services": ["did:sov:LjgpST2rjsoxYegQDRm7EL"]
        }
        """
        let invitation = try OutOfBandInvitation.fromJson(json)
        XCTAssertEqual(invitation.label, "Faber College")
    }

    func testInvitationWithService() throws {
        let json: String = """
        {
            "@type": "https://didcomm.org/out-of-band/1.1/invitation",
            "@id": "69212a3a-d068-4f9d-a2dd-4741bca89af3",
            "label": "Faber College",
            "goal_code": "issue-vc",
            "goal": "To issue a Faber College Graduate credential",
            "handshake_protocols": ["https://didcomm.org/didexchange/1.0", "https://didcomm.org/connections/1.0"],
            "services": [
                {
                    "id": "#inline",
                    "type": "did-communication",
                    "recipientKeys": ["did:key:z6MkmjY8GnV5i9YTDtPETC2uUAW6ejw3nk5mXF5yci5ab7th"],
                    "routingKeys": ["did:key:z6MkmjY8GnV5i9YTDtPETC2uUAW6ejw3nk5mXF5yci5ab7th"],
                    "serviceEndpoint": "https://example.com/ssi",
                }
            ]
        }
        """

        let invitation = try OutOfBandInvitation.fromJson(json)
        if case .oobDidDocument(let didDocument) = invitation.services[0] {
            XCTAssertEqual(didDocument.id, "#inline")
            XCTAssertEqual(didDocument.recipientKeys[0], "did:key:z6MkmjY8GnV5i9YTDtPETC2uUAW6ejw3nk5mXF5yci5ab7th")
            XCTAssertEqual(didDocument.routingKeys?[0], "did:key:z6MkmjY8GnV5i9YTDtPETC2uUAW6ejw3nk5mXF5yci5ab7th")
            XCTAssertEqual(didDocument.serviceEndpoint, "https://example.com/ssi")
        } else {
            XCTFail("Expected OutOfBandDidDocumentService service")
        }
    }

    func testFingerprints() throws {
        let json: String = """
        {
            "@type": "https://didcomm.org/out-of-band/1.1/invitation",
            "@id": "69212a3a-d068-4f9d-a2dd-4741bca89af3",
            "label": "Faber College",
            "goal_code": "issue-vc",
            "goal": "To issue a Faber College Graduate credential",
            "handshake_protocols": ["https://didcomm.org/didexchange/1.0", "https://didcomm.org/connections/1.0"],
            "services": [
                {
                    "id": "#inline",
                    "type": "did-communication",
                    "recipientKeys": ["did:key:z6MkmjY8GnV5i9YTDtPETC2uUAW6ejw3nk5mXF5yci5ab7th"],
                    "serviceEndpoint": "https://example.com/ssi",
                },
                "did:sov:LjgpST2rjsoxYegQDRm7EL",
                {
                    "id": "#inline",
                    "type": "did-communication",
                    "recipientKeys": ["did:key:123", "did:key:456"],
                    "serviceEndpoint": "https://example.com/ssi",
                }
            ]
        }
        """

        let invitation = try OutOfBandInvitation.fromJson(json)
        XCTAssertEqual(try invitation.fingerprints(), ["z6MkmjY8GnV5i9YTDtPETC2uUAW6ejw3nk5mXF5yci5ab7th", "123", "456"])
        XCTAssertEqual(try invitation.invitationKey(), try DIDParser.ConvertFingerprintToVerkey(fingerprint: "z6MkmjY8GnV5i9YTDtPETC2uUAW6ejw3nk5mXF5yci5ab7th"))
    }

    func testRequests() throws {
        let invitation = OutOfBandInvitation(id: "test", label: "test invitation")
        let trustPing = TrustPingMessage(comment: "hello")
        try invitation.addRequest(message: trustPing)
        let requests = try invitation.getRequests()
        XCTAssertEqual(requests.count, 1)

        let request = try JSONDecoder().decode(TrustPingMessage.self, from: requests[0].data(using: .utf8)!)
        XCTAssertEqual(request.comment, "hello")
    }

    func testParseLargeInvitation() throws {
        let url = "http://example.com?oob=eyJAdHlwZSI6Imh0dHBzOi8vZGlkY29tbS5vcmcvb3V0LW9mLWJhbmQvMS4xL2ludml0YXRpb24iLCJAaWQiOiJlODM1NzRjYy1kY2ExLTQwZmEtYWZmMS1kYzg0MDQzOWYzN2IiLCJsYWJlbCI6IkZhYmVyIENvbGxlZ2UiLCJnb2FsX2NvZGUiOiJpc3N1ZS12YyIsImdvYWwiOiJUbyBpc3N1ZSBhIGNyZWRlbnRpYWwiLCJhY2NlcHQiOlsiZGlkY29tbS9haXAxIiwiZGlkY29tbS9haXAyO2Vudj1yZmMxOSJdLCJoYW5kc2hha2VfcHJvdG9jb2xzIjpbImh0dHBzOi8vZGlkY29tbS5vcmcvZGlkZXhjaGFuZ2UvMS4wIiwiaHR0cHM6Ly9kaWRjb21tLm9yZy9jb25uZWN0aW9ucy8xLjAiXSwic2VydmljZXMiOlt7ImlkIjoiI2lubGluZS0wIiwic2VydmljZUVuZHBvaW50IjoiaHR0cDovL2xvY2FsaG9zdDozMDAwIiwidHlwZSI6ImRpZC1jb21tdW5pY2F0aW9uIiwicmVjaXBpZW50S2V5cyI6WyJkaWQ6a2V5Ono2TWtrZXZHemJ6VXNxRVBQeDdwUWJhbkNFNGNTZ2Z4WFBmeVpXU2NjbWd5RmlqRiJdLCJyb3V0aW5nS2V5cyI6W119XSwicmVxdWVzdHN-YXR0YWNoIjpbeyJAaWQiOiI4MDdhMzk1NC02ZjEwLTQ5YmQtYTI1My0zYTU0ZTdiZWRkN2IiLCJtaW1lLXR5cGUiOiJhcHBsaWNhdGlvbi9qc29uIiwiZGF0YSI6eyJiYXNlNjQiOiJleUpBZEhsd1pTSTZJbWgwZEhCek9pOHZaR2xrWTI5dGJTNXZjbWN2YVhOemRXVXRZM0psWkdWdWRHbGhiQzh4TGpBdmIyWm1aWEl0WTNKbFpHVnVkR2xoYkNJc0lrQnBaQ0k2SWpZeU5tRmhOV0ZoTFdFNU9HVXROR1l6WXkwNU5tTmlMVFUxTnpWa1pUY3lNV0ZqTkNJc0ltTnlaV1JsYm5ScFlXeGZjSEpsZG1sbGR5STZleUpBZEhsd1pTSTZJbWgwZEhCek9pOHZaR2xrWTI5dGJTNXZjbWN2YVhOemRXVXRZM0psWkdWdWRHbGhiQzh4TGpBdlkzSmxaR1Z1ZEdsaGJDMXdjbVYyYVdWM0lpd2lZWFIwY21saWRYUmxjeUk2VzNzaWJXbHRaUzEwZVhCbElqb2lkR1Y0ZEM5d2JHRnBiaUlzSW01aGJXVWlPaUp1WVcxbElpd2lkbUZzZFdVaU9pSkJiR2xqWlNKOUxIc2liV2x0WlMxMGVYQmxJam9pZEdWNGRDOXdiR0ZwYmlJc0ltNWhiV1VpT2lKaFoyVWlMQ0oyWVd4MVpTSTZJakl3SW4xZGZTd2liMlptWlhKemZtRjBkR0ZqYUNJNlczc2lRR2xrSWpvaWJHbGlhVzVrZVMxamNtVmtMVzltWm1WeUxUQWlMQ0p0YVcxbExYUjVjR1VpT2lKaGNIQnNhV05oZEdsdmJpOXFjMjl1SWl3aVpHRjBZU0k2ZXlKaVlYTmxOalFpT2lKbGVVcDZXVEpvYkdKWFJtWmhWMUZwVDJsSk0xTXpWa1ZXU0VKU1lVUk9TRk5xWkVoalJGcHlVbGhLZDFZeldrNVBha2syWXpKT2IxcFhNV2hNVjAxM1RrUnJNbHBVVlhoTVZFVXdUMGRSZEU1SFRtaE9VekZwVFhwSmVFeFVTbXRPZWxacVRsUkNiRnBxVlhwWlZHOTRUR3BCYVV4RFNtcGpiVlpyV0RKU2JGcHNPWEJhUTBrMlNXcGtUR1JWVWxWalJrWnZUVEJrUzA0d1pIZE9iWFJHWTI1Q1dHUnJNRFpOZW5CRVZFUnZNVTlVV1RST2VsVTJXa2RXYlZsWVZuTmtRMGx6U1cxMGJHVldPV3BpTTBwNVdsZE9NR0p0Vm5wak1UbDNZMjA1ZGxwcFNUWmxlVXBxU1dwdmFVNTZVVFZPYWxreFRVUm5lRTVFVFRSTmFrMHlUbnBOTkU1NlNUQk5ha1UwVG5wak1FOVVZM3BOUkdONlRXcE5NMDU2YXpST2FtTXdUWHBGZDAxRVRUUk9SRWw2VG5wQk1rOUVTWGxOUkdjMFRVUlZlVTVFUlhoT1ZFVjVUbFJWTVUxNlNURk9WRUZwVEVOS05HVnNPV3BaV0VGcFQybEplVTVxVFRKTlZFRTFUWHBWZVU1cWEzZFBSR3Q2VFVSSmVVNVVZekJPYWxFMVRrUlZNVTFVVFRST2FsbDRUbnBaZUUxVVZUTk9la0Y0VGtSak1rMTZTVFJQUkVsNlRWUkZNVTE2VVRCTmVtdDZUV3BqTWs5VVNUSk5SRTAwVFVSRmQwNUVRWHBQUkVrd1RucFJkMDFVUVRSTlJGRTFUWHBGTkUxVVRUUk5ha0V5VDBSVk5FOVVaM3BPUkVWNFRVUmplRTVVVFRCT1ZHTjRUa1JSZDA5VVVUSlBSRkYzVGtSak1FMVVWWHBPYWtsNVRYcE5OVTFVV1hoTlZHTTBUV3BSTTAxcVJUTlBWRWw2VG5wcmVVMUVSVEJPUkZFMFRWUmplazFFUlhwTlJGVTBUMFJCTVU5RVNYZE9SR013VG1wak0wNVVSWGxOVkVreFQxUlJOVTVFUVhsT2VtTXhUMVJqZUUxVVp6Qk9WRVV3VFZSak1VMVVVWGxPZWxWNlQxUlZNVTU2YXpGUFZFRTBUMFJGTlU5RVkzcE5WRmw0VFVSTk5VNTZXVEpOUkZFMVQwUnJNazVFU1RWTmFtY3lUbXBqTkUxNlVUVk9hbXN4VG1wVk5VNTZWVE5OVkVWNVRucE5lVTFFUlRGT1JGRXpUbFJqTkU1cVkzbE9SR00xVG5wTmVVMVVSVEJOZWxrd1RVUlpNRTU2U1hoTmFtZDNUa1JCTUU5RVNYZE5lbEV4VGtSbmVVNXFZM2hPUkVreFQxUm5NMDU2WjNwT1JFbDVUa1JyZDA1RVZUQk9lbU13VG5wTmVrMXFVVEpOVkdOM1RsUkZORTE2WnpCTlJFa3dUa1JWTTAxNlZYbE5la1V5VFVSUk1FOVVRVEZPZWtreFRVUkZORTFxVlRCT2VrRjZUV3BOTlU1VVNUTk5lazAwVFZSQk5FMVVRVEJOZWsxNFRYcG5NazU2WjNsT1ZHc3hUMVJaTTAxNll6Uk9SRWw0VGtSbk1FNXFZM2hPZWtFMFRrUlpNRTlFUVRGT2VrVjRUbnBSZUUxRVp6Sk9SRVUxVFVSVmQwNXFTVEpPYWxVMFRXcGpNazU2UlhkT1JFRTFUVlJaZUU5VVp6RlBSR014VDBSSk0wOVVTWGRPYWxrd1QxUkpNazVFV1RCTmFtZDVUVlJKTlU1cVl6Rk9hbFYzVDFSSmVrMUVZelZPYWxFMFRYcFJkMDE2VlhkUFJFa3dUa1JWTWsxRVozaE5ha0V4VFhwSk5VNTZSVFZOYWxFd1RsUmpNazU2UVhwT1ZGVXpUWHByZWsxcVl6Sk9WRmswVDBSTk1VNUVUWGRQUkdzMVRWUlZlazU2YXpWT1JHc3hUMFJSZWs5RVdUVk9ha0UxVFZSQmVVNXFZM2hPZW1jd1RWUlJNRTlFWXpCT2FtTXlUbnBKTUU1VVFURk9hbEYzVFZSTmVVNXFRVEJPZWxVMFRtcGplRTVxVVhoUFZGRXlUVlJuTWs1VVRUVk9hbWQ1VFhwRk1FOUVRWHBOZWxFeFRWUkpkMDU2UVhwT2VsVjRUMVJWTlU1VVVUTlBWR3QzVGtSQk0wNTZXVEZPZW1NelRYcEZNMDE2YXpKUFJGRXpUbnBWTUUxcVVUUlBSR2Q2VGxSRmFVeERTalJqYkRscVdWaEJhVTlzZEdKSmJUVm9ZbGRWYVV4RFNYaE5lbGswVGtSTmVVMVVUWHBOZW1kM1QxUkJOVTlFUlhoTlZGazFUV3BaTkU5RWEzcFBWR2MxVG1wUmVrOUVSVEJPUkVVelRrUlZNRTVFUVhsTlZGa3dUbnBWTWsxRVkzZFBSR00xVFdwVk0wMXFhekZOVkZreVRXcGplazlVVlhwTmFsRXhUbXBGTkU1cVFUTk5la2wzVFVSSk0wOUVXVEZOUkVWNlRWUkplRTVVU1RGT1ZFVXdUV3BCTWs1RVdUTk5lbU0wVG5wcmVVNTZZelJQUkdzelQwUkZORTVVYTNkT2FtdDVUbnBWTkU1VVNUSk9SRkY2VG1wUk5FOVVaM2hOUkZGNVRVUkJNRTVxUVhsUFJFbDRUVlJqTWs1cVl6TlBSRTB4VDFSQmVFNTZWVEpOYWtFMVRVUm5lazlVUVhoT1JFVjVUbnBCZUUxRVNUSlBSRlV5VDFSWk1VMVVXVEZOZW10M1RucG5NVTVVVlhsT2VrMDFUV3BGZWs1RVkzcE5hbGwzVFVSUk5VOVVXWHBOZW1zeVRrUkZkMDE2VVhsUFJFRXhUbnBaTTA1Nll6Vk9lbXQ0VG5wUk1rNTZRWHBPVkUwd1RrUlplRTFFYXpOTlZFbDNUbnBGTWsxNlVYcE5WRVY2VDBSUmQwNVVUWGxPYW1ONlQwUlJOVTFxUlRKT2VrRTBUVlJaZUU1cVFUQk9WRVV3VGtSVmVFMVVTVEJOYWxVd1RVUm5kMDE2UlRKUFJFa3hUVVJGTkU1cVNURk9SR2N6VG5wUmVFNVVTVEpOVkdONlRVUm5lRTVxYTNkTlZFRjZUWHByTTAxVVNUTk5WRVY2VFdwUmVVOUVRVFJPYW1zd1RWUkpORTU2UVRST2VsRTFUbFJOZVU1NlkzbFBWRTE2VGtSbk1rOUVZM3BOYW10NlRWUmplVTFFUVRSTmFtTjNUMFJGZDA1RVRUTlBSRmw0VDBSWk0wMTZZelZOVkVGNlRtcG5NVTVFYXpOUFJGRXhUbnBSTVU1RVdUVlBWRlV6VGxSRmQwNXFWVFJOUkVreFQwUlJNVTlVWTNoUFZHc3hUVVJSTUU1cVdUUk9lbGt3VG5wUmVrNUVVWGhQVkdONVRYcEpNMDE2U1hoUFZHY3dUV3BaTkUxcVZUTk9WRkV5VDFSQk5FMTZUVFJPVkZrMVRYcHJOVTVFWnpOTmFtY3hUMVJGTTA1NldYZFBSR3N5VFdwTk0wOVVTVFZOYWtsNVQwUlZNRTVxVVhwUFZHczFUMVJWTWsxVVRURlBWRVV6VGxSSmVrMXFaM2xPZWtWNFRWUnJORTE2UVRSTlZGVXpUa1JyTUU1VVp6Rk5la0Y0VFdwcmVVNTZWVE5PUkdNMFRXcEJOVTlVUlROT2FsRXpUa1JyZVU1cVJYZE9WRkYzVFdwWmVrNTZaM3BQUkZWNFRVUlpNVTU2V1hkT1JGbDVUWHBKTVU1RVZUVk5WRWswVDBSUk0wNUVSVEpPZW1NMVRrUlZNazVxVlhoTmFtZDNUa1JSTUUxVVJYcE9WRmsxVDFSTmVVNVVUVEJPUkVGNFRtcEpORTlVVVRKT2FrMTVUbFJyZUU5RVFYbE9hbU15VFhwVk5VOVVXVFJPUkdzMVRWUk5lVTlFUlRWSmJEQnpWM2xLZEZsWVRqQmFXRXBtWXpKV2FtTnRWakJKYVhkcFRrUlZNVTVVVlRKTmFrMDBUMFJSTTA5RVJYaFBSRTAwVFdwWk5VOVVSVEZOVkdNeFRrUlplazlFV1hkTlJHZDVUbFJOTlUxcVl6Uk5lbEV4VGxSQmVVNUVTWHBOVkUxM1QxUkZNazU2VlRWUFZFa3pUVVJqZWs5VWEzcE9SR00xVG1wTmVrNTZTVE5PZWtsM1RXcGpORTFFWjNkT1ZFazFUMFJuTlU1NmF6RlBSRUV3VG5wQk5FMVVZM2xOUkVrMVRWUlJlVTFxVVRKT1JFbDRUMFJaZVU1NlRYcE9WR3Q0VG1wSk1VMVVSVFJPVkZGNVRtcFZlRTlVUVhsT1JGRjRUVVJSZDA1RVZYcE9SRTE1VFZSQk1rMTZZelJOUkUwMFRrUm5lazlFU1RKT1JHTjNUMFJGZWs5RVRUUk5SRkV4VFVSck5FMTZZekJOVkUwelRXcHJORTlVUVRWTmFsRXhUV3BKTVUxRVdYZE5WRUUxVFdwbmQwNUVSWHBOVkdNeFRsUlJOVTU2VFhoT2Vra3hUVlJaZVU5VVJYZE5lbU13VDFSSk1FOUVaelJOYW1zd1RucFZlazlFUlhsUFJHZDNUbXBKTWs1NlVYaFBSRmwzVDBSQmQwNUVSVEpPYW1zd1RsUkZNMDE2UlhsUFZHZDVUWHBWTlU5RVFYbE9WRTB5VGxSbmVVNXFXWGhOZWtWNFRrUm5lazFFU1ROUFJGVTBUbXBuTWsxcVdUTk9WRkUxVFdwSmVFMTZTWHBQUkZGM1RXcGpNRTE2UlRGUFZHZDZUV3BOZWs1RVZUVlBSRkV4VFZSSk1VNVVVVE5PVkVrd1QxUk5lazlVUVRSTlZHc3lUMFJOTTA1VVNUVlBSRlY1VDFSUk1FMVVhM3BPVkVrMVRWUkpNVTVxUVRGT2FtY3dUV3BGTlU1VWF6Rk9hazB6VGxSbk1rNUVWVFJPYW1NeFRucEJlRTlVWTNoTlJFMDBUMVJaTkU1cVFUUk5lbFY0VFhwbk5FMUVSWGhPYWxreFRVUlZNVTU2VlhwT1JFMDBUbFJSTWsxNlFYcFBSRWt4VFZSbk0wNTZRVEpPZWtVd1RWUlZNazVVWXpCTmVrRjNUMVJaTkUxRVJUQk9SRVV3VFdwRk5FNUVTWGxPZWxVelRsUlZlVTE2VVRWT2Vsa3dUWHBWTlUxRVFURk5WR3MwVGtSbk1FNVVSWGhPYWtGNlRsUm5lazU2WTNkTlZHTTBUVlJyTVUxcVRYbE5WR3N6VGxSVk0wNXFXVFJOUkZWM1QwUlZNazlFWXpCTlJFbDZUbFJKZDA1RVl6Sk9SRWw2VFVSamQwMTZUWGRPVkZreVRsUkpNRTFxVVhsT2FtczBUbnBGTlUxNlRYZE9hazAxVG5wVk1FNTZUWGxOUkUwMFRsUk5OVTFFVlhwTmVsRXdUMFJyTWsxNlNUSk9SRWw0VFZSak5VOUVhek5PUkZVMFQwUk5kMDlFV1RST2VsVXdUMVJaZUUxcVkzaE5SR016VFVSQmVFOVVUWGRPUkZWNFRtcG5OVTVxVlRST2VsbDVUVlJCTUU5VVVUSk5SRWw2VDBSak1rOVVVWGhPZWsxNlRsUmplRTVVV1hoUFJGRXhUbXBCZUUxRVkzaE9WRVV3U1d3d2MxZDVTbWhhTWxWcFRFTkplRTFxVFhkTlZHczFUbnBCTlU5RVFUQk9ha2sxVFdwWk0wMXFRWGhQVkUwd1RXcG5NVTFVWXpCT1ZFVXpUMVJCTUU5RVZYZE9SRUV6VGtSSmVrOVVXVEJQVkVVMFQwUmpOVTlFUlhoUFJFVXhUWHBSTUUxRVNYcE5SR2N6VFVSak1VOVVXVFJPYWxWNlQwUkZkMDFxWXpOTmFrbDZUa1JuTkU1VWEzcE5WR3N6VFdwVmVVMTZXVFZQUkUxNVRWUlZORTFVV1ROTlJHTjNUV3BuTkU5VVJYcE5hbFV6VFVSbk1VNUVWVFZPUkUxM1RucHJlRTU2V1RGT1ZHZDVUWHBqZWs5RVFUQlBSRTE2VDFSak0wOVVWWGhOUkZFelRXcG5kMDU2U1RKT2FsRXpUbFJyTVU1NldUTk9lbXN4VGtSak1rOVVZM2hQVkZVeFQxUmplRTU2UVRCTlZFMTVUbnBSTWs1VVVUUlBSRmw2VG1wUk1rNUVZekJPYW10NVQwUkZOVTFxYXpSTmVtczFUWHBuTlUxVVVUUlBWRVY2VG5wWk1rNUVRWGRPVkVVeFQwUlJlazFFUlROT1JHc3lUbFJaTTAxNlkzcE5SRlV5VFVSSk5VOVVSVEpQVkZVelRYcFJlazFxWnpGT1ZFVjRUbXBOZUU5RVRUSk9SR2MwVFhwTmVFNUVTWHBQUkdzeFRrUmpNRTVFV1RGTlZHZDVUVlJGTTA1cVRYbE9ha0UwVFZSQk5FOUVUVEJPUkZVelQwUkpNVTVVUVhsUFZFVjZUVVJWTlU1VVl6Rk9WR3N5VG5wTk1VMUVXVEZPUkZFeFRsUlplazlFYTNoTlZHYzBUMFJqTkU1VVFUUk9WR016VFdwSk0wNTZUWGhPYWtrMFQxUkZNMDFxUVRCT1JFMHlUbFJWTWs1VVkzaE5la0YzVG5wWk0wNXFUVFZOUkVrMFRVUkZlazE2WXpKUFZFVjRUMVJSZWsxRVkzaE5SRlY2VGxSVk5VMVVSWGROUkdzeVQxUkJlVTVVUVhoTlZHY3lUMFJqZVU1cVNUTlBSRVYzVFdwRmVFOVVUVEJQUkZrd1RsUk5lRTVxWTNoT1JFMTVUVVJKTTA1RVRUSk9WRUUxVG5wSmVFOUVVVE5OYW10NVRXcEJNRTlFUVRWTmFsRTFUbFJuTVU1NlJYbFBSRkUxVFhwRk1rMVVXVEJQUkdNd1RXcGpNazVxVlRGTmFrRjNUWHBKTkU1VVozcE9WRVUxVDBSTk1FMVVWWGRQUkdzd1RVUkJNVTFVUVRGT2VrVTBUV3BKZDAxNll6Qk9SR2Q0VFVSbk1rMVVVWGxQVkdkNFRXcGplVTVVVlRCUFZGVXdUa1JWTTAxRVJYaE5SR014VFVSVk0wNVVhekJQVkVrMVRrUlZNVTFFWjNwT1JHY3pUbFJCTlU1VVJYcE5lazB4VFdwSmVVNUVZek5PUkZsNVQwUmpNVTE2UVROT2VtY3lUV3BqZDA1NlZUTk9hbGw0VGtSSmVVNTZWVE5OVkUwelRVUnJlRTFxVVROT2VsRTBUVlJuZDAxNlJUUk5hbFY0VDFSbk0wMVVSVFZOYW10M1QwUkJlazFxVFROT2Fra3lUVVJOTTAxRVl6Rk9SR00xVGxSak1VbHNNV1JtVTNkcFltMDVkVmt5VldsUGFVa3dUMFJCZWs5VVJYZFBSRmt4VDBSWmVFMXFVVEZOUkVFd1QxUkplRTVxWjJsbVVUMDlJbjE5WFgwPSJ9fV19"
        let invitation = try OutOfBandInvitation.fromUrl(url)

        XCTAssertEqual(invitation.goalCode, "issue-vc")
        XCTAssertEqual(invitation.requests?.count, 1)
    }
}
