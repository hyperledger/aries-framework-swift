
import XCTest
@testable import AriesFramework

class AgentTest: XCTestCase {
    let mediatorInvitationUrl = "http://localhost:3001/invitation"
    let agentInvitationUrl = "http://localhost:3002/invitation"
    let publicMediatorUrl = "https://public.mediator.indiciotech.io?c_i=eyJAdHlwZSI6ICJkaWQ6c292OkJ6Q2JzTlloTXJqSGlxWkRUVUFTSGc7c3BlYy9jb25uZWN0aW9ucy8xLjAvaW52aXRhdGlvbiIsICJAaWQiOiAiMDVlYzM5NDItYTEyOS00YWE3LWEzZDQtYTJmNDgwYzNjZThhIiwgInNlcnZpY2VFbmRwb2ludCI6ICJodHRwczovL3B1YmxpYy5tZWRpYXRvci5pbmRpY2lvdGVjaC5pbyIsICJyZWNpcGllbnRLZXlzIjogWyJDc2dIQVpxSktuWlRmc3h0MmRIR3JjN3U2M3ljeFlEZ25RdEZMeFhpeDIzYiJdLCAibGFiZWwiOiAiSW5kaWNpbyBQdWJsaWMgTWVkaWF0b3IifQ=="
    var agent: Agent!

    class CredentialDelegate: AgentDelegate {
        let expectation: TestHelper.XCTestExpectation

        init(expectation: TestHelper.XCTestExpectation) {
            self.expectation = expectation
        }

        func onCredentialStateChanged(credentialRecord: CredentialExchangeRecord) {
            print("credential state changed to \(credentialRecord.state)")
            if credentialRecord.state == .Done {
                expectation.fulfill()
            }
        }
    }

    override func tearDown() async throws {
        try await super.tearDown()
        try await agent.reset()
    }

    func testMediatorConnect() async throws {
        var config = try TestHelper.getBaseConfig(name: "alice")
        config.mediatorPickupStrategy = .Implicit
        config.mediatorConnectionsInvite = publicMediatorUrl
        class TestDelegate: AgentDelegate {
            let expectation: TestHelper.XCTestExpectation
            init(expectation: TestHelper.XCTestExpectation) {
                self.expectation = expectation
            }
            func onConnectionStateChanged(connectionRecord: ConnectionRecord) {
                print("connection state changed to \(connectionRecord.state)")
            }
            func onMediationStateChanged(mediationRecord: MediationRecord) {
                print("mediation state changed to \(mediationRecord.state)")
                if mediationRecord.state == .Granted {
                    expectation.fulfill()
                } else {
                    XCTFail("mediation failed")
                }
            }
        }

        let expectation = TestHelper.expectation(description: "mediator connected")
        agent = Agent(agentConfig: config, agentDelegate: TestDelegate(expectation: expectation))
        try await agent.initialize()
        try await TestHelper.wait(for: expectation, timeout: 5)
    }

    func testAgentInit() async throws {
        var config = try TestHelper.getBaseConfig(name: "alice")
        config.mediatorConnectionsInvite = try String(data: Data(contentsOf: URL(string: mediatorInvitationUrl)!), encoding: .utf8)!
        class TestDelegate: AgentDelegate {
            let expectation: TestHelper.XCTestExpectation
            init(expectation: TestHelper.XCTestExpectation) {
                self.expectation = expectation
            }
            func onConnectionStateChanged(connectionRecord: ConnectionRecord) {
                print("connection state changed to \(connectionRecord.state)")
            }
            func onMediationStateChanged(mediationRecord: MediationRecord) {
                print("mediation state changed to \(mediationRecord.state)")
                if mediationRecord.state == .Granted {
                    expectation.fulfill()
                } else {
                    XCTFail("mediation failed")
                }
            }
        }

        // test init with mediator

        let expectation = TestHelper.expectation(description: "mediator connected")
        agent = Agent(agentConfig: config, agentDelegate: TestDelegate(expectation: expectation))
        XCTAssertEqual(agent.isInitialized(), false)
        try await agent.initialize()
        XCTAssertEqual(agent.isInitialized(), true)

        // test init with mediator after shutdown

        try await agent.shutdown()
        XCTAssertEqual(agent.isInitialized(), false)
        try await agent.initialize()
        XCTAssertEqual(agent.isInitialized(), true)
        try await agent.reset()

        // test init without mediator

        config.mediatorConnectionsInvite = nil
        agent = Agent(agentConfig: config, agentDelegate: nil)
        XCTAssertEqual(agent.isInitialized(), false)
        try await agent.initialize()
        XCTAssertEqual(agent.isInitialized(), true)
        try await agent.reset()
        XCTAssertEqual(agent.isInitialized(), false)
    }

    /*
     Run two javascript mediators as follows:
       $ AGENT_ENDPOINTS=http://localhost:3001 npx ts-node mediator.ts
       $ AGENT_PORT=3002 AGENT_ENDPOINTS=http://localhost:3002 npx ts-node mediator.ts
     */
    func testAgentConnect() async throws {
        var config = try TestHelper.getBaseConfig(name: "alice")
        config.mediatorConnectionsInvite = String(data: try Data(contentsOf: URL(string: mediatorInvitationUrl)!), encoding: .utf8)!
        class TestDelegate: AgentDelegate {
            let expectation: TestHelper.XCTestExpectation
            var connectionCount = 0
            var connectionCommand: ConnectionCommand?
            init(expectation: TestHelper.XCTestExpectation) {
                self.expectation = expectation
            }
            func onConnectionStateChanged(connectionRecord: ConnectionRecord) {
                print("connection state changed to \(connectionRecord.state)")
                if connectionRecord.state == .Complete {
                    connectionCount += 1
                    if connectionCount == 2 {
                        expectation.fulfill()
                    } else if connectionCount == 3 {
                        XCTFail("Too many connections")
                    }
                }
            }
            func onMediationStateChanged(mediationRecord: MediationRecord) {
                print("mediation state changed to \(mediationRecord.state)")
                XCTAssertEqual(mediationRecord.state, .Granted)
            }
        }

        let anotherInvite = String(data: try Data(contentsOf: URL(string: agentInvitationUrl)!), encoding: .utf8)!
        let invitation = try OutOfBandInvitation.fromUrl(anotherInvite)

        let expectation = TestHelper.expectation(description: "Two connections are made")
        let testDelegate = TestDelegate(expectation: expectation)
        agent = Agent(agentConfig: config, agentDelegate: testDelegate)
        try await agent.initialize()
        _ = try await agent.oob.receiveInvitation(invitation)

        try await TestHelper.wait(for: expectation, timeout: 5)
    }

    // Run faber in AFJ/demo/ and run mediator in AFJ/samples before this test
    func testDemoFaber() async throws {
        var config = try TestHelper.getBcovinConfig(name: "alice")
        config.mediatorConnectionsInvite = String(data: try Data(contentsOf: URL(string: mediatorInvitationUrl)!), encoding: .utf8)!

        let expectation = TestHelper.expectation(description: "credential received")
        let testDelegate = CredentialDelegate(expectation: expectation)
        agent = Agent(agentConfig: config, agentDelegate: testDelegate)
        try await agent.initialize()

        let faberInvitationUrl = "http://localhost:9001?oob=eyJAdHlwZSI6Imh0dHBzOi8vZGlkY29tbS5vcmcvb3V0LW9mLWJhbmQvMS4xL2ludml0YXRpb24iLCJAaWQiOiI3MWQxN2IzZS01NWM0LTQwZGItOTg3ZC02OTdhY2YyNmMzMzgiLCJsYWJlbCI6ImZhYmVyIiwiYWNjZXB0IjpbImRpZGNvbW0vYWlwMSIsImRpZGNvbW0vYWlwMjtlbnY9cmZjMTkiXSwiaGFuZHNoYWtlX3Byb3RvY29scyI6WyJodHRwczovL2RpZGNvbW0ub3JnL2RpZGV4Y2hhbmdlLzEuMCIsImh0dHBzOi8vZGlkY29tbS5vcmcvY29ubmVjdGlvbnMvMS4wIl0sInNlcnZpY2VzIjpbeyJpZCI6IiNpbmxpbmUtMCIsInNlcnZpY2VFbmRwb2ludCI6IndzOi8vbG9jYWxob3N0OjkwMDEiLCJ0eXBlIjoiZGlkLWNvbW11bmljYXRpb24iLCJyZWNpcGllbnRLZXlzIjpbImRpZDprZXk6ejZNa2dpb0N2V2pHWkhEZzhtdFF1NW8zOG5LdHF1RnRIUzM0dWI3UTRjZnRBbmthIl0sInJvdXRpbmdLZXlzIjpbXX0seyJpZCI6IiNpbmxpbmUtMSIsInNlcnZpY2VFbmRwb2ludCI6Imh0dHA6Ly9sb2NhbGhvc3Q6OTAwMSIsInR5cGUiOiJkaWQtY29tbXVuaWNhdGlvbiIsInJlY2lwaWVudEtleXMiOlsiZGlkOmtleTp6Nk1rZ2lvQ3ZXakdaSERnOG10UXU1bzM4bkt0cXVGdEhTMzR1YjdRNGNmdEFua2EiXSwicm91dGluZ0tleXMiOltdfV19"
        let invitation = try OutOfBandInvitation.fromUrl(faberInvitationUrl)
        print("Start connecting to faber")
        _ = try await agent.oob.receiveInvitation(invitation)

        try await TestHelper.wait(for: expectation, timeout: 120)
    }

    // Run faber in AFJ/demo/ in legacy_connection branch
    func testDemoFaberWithLegacyConnection() async throws {
        let config = try TestHelper.getBcovinConfig(name: "alice")
        let expectation = TestHelper.expectation(description: "credential received")
        let testDelegate = CredentialDelegate(expectation: expectation)
        agent = Agent(agentConfig: config, agentDelegate: testDelegate)
        try await agent.initialize()

        print("Getting invitation from faber")
        let faberInvitationUrl = "http://localhost:9001/invitation"
        let faberInvite = String(data: try Data(contentsOf: URL(string: faberInvitationUrl)!), encoding: .utf8)!
        let invitation = try ConnectionInvitationMessage.fromUrl(faberInvite)
        print("Start connecting to faber")
        _ = try await agent.connections.receiveInvitation(invitation)

        try await TestHelper.wait(for: expectation, timeout: 120)
    }

    // Run AriesFrameworkTests/javascript/Faber.ts and copy the invitation from the console.
    func testReceiveCredentialThroughOOB() async throws {
        let config = try TestHelper.getBcovinConfig(name: "alice")
        let expectation = TestHelper.expectation(description: "credential received")
        let testDelegate = CredentialDelegate(expectation: expectation)
        agent = Agent(agentConfig: config, agentDelegate: testDelegate)
        try await agent.initialize()

        let oobInvitation = "http://example.com?oob=eyJAdHlwZSI6Imh0dHBzOi8vZGlkY29tbS5vcmcvb3V0LW9mLWJhbmQvMS4xL2ludml0YXRpb24iLCJAaWQiOiIwMDE2MzQ5Yi1kYjVlLTRiOGYtODAyYy1jYTI2MmZhNTYxZWUiLCJsYWJlbCI6IkZhYmVyIENvbGxlZ2UiLCJnb2FsX2NvZGUiOiJpc3N1ZS12YyIsImdvYWwiOiJUbyBpc3N1ZSBhIGNyZWRlbnRpYWwiLCJhY2NlcHQiOlsiZGlkY29tbS9haXAxIiwiZGlkY29tbS9haXAyO2Vudj1yZmMxOSJdLCJoYW5kc2hha2VfcHJvdG9jb2xzIjpbImh0dHBzOi8vZGlkY29tbS5vcmcvZGlkZXhjaGFuZ2UvMS4xIiwiaHR0cHM6Ly9kaWRjb21tLm9yZy9jb25uZWN0aW9ucy8xLjAiXSwic2VydmljZXMiOlt7ImlkIjoiI2lubGluZS0wIiwic2VydmljZUVuZHBvaW50IjoiaHR0cDovL2xvY2FsaG9zdDozMDAwIiwidHlwZSI6ImRpZC1jb21tdW5pY2F0aW9uIiwicmVjaXBpZW50S2V5cyI6WyJkaWQ6a2V5Ono2TWt1ODJmRVNOZ0pNQ2ZIa2hlUW1obnZKemt4VFlEQVA1cm9vVVZTVGJtSmc2ZSJdLCJyb3V0aW5nS2V5cyI6W119XSwicmVxdWVzdHN-YXR0YWNoIjpbeyJAaWQiOiI5YTQzMTFhZS1jM2M0LTQ4NzItYTE2MC1mMDA0YWY2ZDZiZDAiLCJtaW1lLXR5cGUiOiJhcHBsaWNhdGlvbi9qc29uIiwiZGF0YSI6eyJiYXNlNjQiOiJleUpBZEhsd1pTSTZJbWgwZEhCek9pOHZaR2xrWTI5dGJTNXZjbWN2YVhOemRXVXRZM0psWkdWdWRHbGhiQzh4TGpBdmIyWm1aWEl0WTNKbFpHVnVkR2xoYkNJc0lrQnBaQ0k2SWpNM05tUmpOVEJtTFRCa01qTXROR1UwTVMwNE5qZ3lMVEZtWXpabU56UmlOemxtWlNJc0ltTnlaV1JsYm5ScFlXeGZjSEpsZG1sbGR5STZleUpBZEhsd1pTSTZJbWgwZEhCek9pOHZaR2xrWTI5dGJTNXZjbWN2YVhOemRXVXRZM0psWkdWdWRHbGhiQzh4TGpBdlkzSmxaR1Z1ZEdsaGJDMXdjbVYyYVdWM0lpd2lZWFIwY21saWRYUmxjeUk2VzNzaWJtRnRaU0k2SW01aGJXVWlMQ0oyWVd4MVpTSTZJa0ZzYVdObElGTnRhWFJvSW4wc2V5SnVZVzFsSWpvaVpHVm5jbVZsSWl3aWRtRnNkV1VpT2lKRGIyMXdkWFJsY2lCVFkybGxibU5sSW4wc2V5SnVZVzFsSWpvaVpHRjBaU0lzSW5aaGJIVmxJam9pTURFdk1ERXZNakF5TWlKOVhYMHNJbTltWm1WeWMzNWhkSFJoWTJnaU9sdDdJa0JwWkNJNklteHBZbWx1WkhrdFkzSmxaQzF2Wm1abGNpMHdJaXdpYldsdFpTMTBlWEJsSWpvaVlYQndiR2xqWVhScGIyNHZhbk52YmlJc0ltUmhkR0VpT25zaVltRnpaVFkwSWpvaVpYbEtlbGt5YUd4aVYwWm1ZVmRSYVU5cFNYbGhhMVl5Vlc1V1RHSlhXa05UYkZKVFdWUmtVbUl6WkVWalJUVlBUMnBKTmxKdFJtbGFXRWxuVVRJNWMySkhWbTVhVkZsM1dtMUZOVTR5VlhoTVZHY3lUVmROZEU1SFdYbFphVEZvVFVSQ2JFeFVVWGRaZW1SclRYcE5NMDVFV21oYVZHOTRUR3BCZFUxRFNYTkpiVTU1V2xkU1pscEhWbTFZTW14clNXcHZhVTF0Y0Vaa2JFb3hVekl4YlZGcmNGVlZiVVV6VlZjNU0xSklRazlVYW05NlQydE9UVTlxVVhsTmVtTjZUV3B3YzFsWVVteGpNMUZwVEVOS2NscFliR1paTWpsNVkyMVdhbVJITld4ak0wNW1ZMGhLZG1JeVdXbFBibk5wV1hsSk5rbHFXWHBQVkUxNVRXcFJNazVFUVhwUFZFRTFUVVJSTVU5VVNYZE5ha0Y2VDBSTk1FOVVWWGhPUkZGM1QwUnJNRTU2WjNoT1JFMTNUV3BCZDA1VWF6VlBSRVV6VGtSSk1rNUVUVEpOZWxrMFRucEJNazFVVFRSTmVrMDFUMVJKTUU1Nlp6Uk9SRTB4U1dsM2FXVkljR1paTWtaM1NXcHZhVTVxVVhoTmVrRTBUbnBCZWsxNldUUk5WRkUwVGtSWk0wOVVVVEJOUkVsNlRYcG5NRTFFV1hoTmFrVTBUMVJyTTAxcVVYbE5WRWt6VDFSRk1rNTZXVEZOZW10M1QwUkJkMDFFVVRGT1ZFRXhUVlJqTlU1RVJYbE5SR2N3VDFSTk1rMUVUVEZOUkdjMFRVUkZNMDFxV1hwTmVra3hUMFJWZWs1VVJURk9lbGt6VG5wUk0wMUVXWHBOUkZGNVRYcHJNRTU2UlROT2VtYzFUbXByZWsxNlVUVk5SR014VFhwSk1VNUVZM2xPVkdONlRWUkpNVTU2V1hsT2FrMHlUMVJOTWs5VVFYZE9WRmw1VFhwck5FOVVZekJOUkZVMVQxUk5lazVxVVhoTmFtdDRUbnBSZUU5VVZUSlBSR3MwVDBSQk0wNVVXVE5OVkUxM1RucFplazU2UVRKT1ZGRTBUbnBqZDA1RWF6Vk9hbWN4VFhwSk1VOVVXVEJOYWtrelRtcEJlVTVFWXpKUFJHTTFUMFJuTUUxRVkzbE5WRUV6VFhwQmVrNTZXVEZPUkVsNlRYcGpNVTVxVFhkUFJHTXpUVlJGZDAxcVRUUk9SRlV6VFdwbk1VMXFSWGhOUkVFd1RWUkJlazFVYXpCTmFtdDNUVlJOTlU1RVdUQk9WRUV5VG5wTk5VMVVRWGxOVkUwd1RtcFJlRTVVV1RSTmFsVTFUMFJGTUUxVVNYbE9WRkV5VGxSRmVFNUVZekpPUkUweFRrUlZOVTVxWTNkTlZFRjRUa1JqTkUxVVZUSk5WR015VFVSRmVFNTZRVEJPZW1kM1RWUlZNMDVxWTNoUFJGa3dUMVJaTUUxcVVYbE5WRlUxVDBSRmVVNVVWVFJQVkZWNFQxUlZlRTFVU1RWTlJFRXpUbnBCTUU5VVdUSk5lbFYzVGtSRk1rNXFTVEJPYWxVelQwUlplazVVWjNkTlZGRXlUa1JyZDA1cVdYZE5lbEYzVFZSRk1VNXFaekJPVkVrMFQxUkpNRTlVU1hoT2FsVXhUMFJOZDAxcVVYaE5SRTB3VG5wSk5FMVVRVEJPZWsweFRsUk5NVTFxYXpGT2FtTTFUbnBCTVUxRVNUSk9la0Y0VFdwWk5VNUVhek5QUkVrMVQxUk5NMDU2VFRCUFZFMTRUa1JyTVU1VWEzcE5hbEV4VG1wTk5FNTZhM3BPVkd0NlQwUlZNazU2UVRCTmVsVXlUVlJCZDA5RVJUTk9hbGswVFZSbmVVNVVWVEZQUkZVeFRrUkpORTFVV1ROUFZFbDNUVVJqZWsxVVZUTk5la0Y1VG5wSk1VNTZUWGhOYW1jeVRrUk5NRTFxYTNwTmVtTXhUbFJyTlU1VVJUSk5SR015VG1wUk1FOVVVVFJQUkZVeFRVUkJlRTVxUVhoT2FrMTRUVlJWZWs5VVZUSlBSRWt3VFhwTk0wOVVaM2ROZWxFelRucHJlRTVxV1RGTlZFazBUV3ByTUU1VVp6Sk9la2w2VG5wRk1rOVVSVEpOZWsweVQxUlZNMDFFVlhkTlZGRjVUWHBaTlU1NlZYaE5lbWN3VDFSQmQwMVVaek5OZWtVeVRWUkZNMDFxWXpKTmVtY3pUbFJKZVUxNldYbE9WRlYzVFVSUk0wbHBkMmxsU0VwbVdUSkdkMGxxY0dKWGVVcHJXbGRrZVZwWFZXbE1RMGswVG1wWk5VMXFhelJOUkdkM1RVUmplRTFFVFRGT2VrRXpUVVJuTWs1RVFUQk5SRVYzVGtSQk5VMXFaekZOVkVGM1QxUlJlRTVFV1ROT2VtTXhUbFJuZDAxcVdYaFBWR2QzVGxSTmVFMXFZM2xPVkVFeFRYcG5ORTVxUlRWTmVtTjVUV3BuTUU5RVJUUk9hbU0xVFhwbmVrMVVZekpOZWtVMVRWUkplazFVUVRWUFZHYzBUbnBSZWs1cVFUQk9lbGw2VG1wVk0wOUVaM2hQUkVFeFRrUlZlRTFxVVRSTmVrMHpUWHBaTVUxcVdYbFBWRlY1VFhwWk5FOUVXVE5OZWtGNlRtcHJOVTVFV1hwT1JFVXdUV3BqTVU1VVVUSk9ha0YzVFdwcmQwOVVRWGxPVkVWNFRtcEplazlVYTNwTlJFVXdUV3ByZDA5RWF6Sk5hbFUwVGtSRk1rOVVhek5PVkVVeFRYcEpNMDFxVFRKUFZFMHdUVlJCZWsxVVl6Tk9SRTAwVGxSTmVrOUVSVFZOVkdjd1RtcEJNVTlFV1hoUFZGazFUbnBKTVUxRVFUQlBWRkV4VDFSQmVFNXFWWGxPYWtGNVRYcGpORTVVUlROTlJGVTBUMVJGZDA5RVFYbE5SR3N5VFZSck1rNVVTWGRPVkVGNVQwUnJlVTU2UVRST1JHc3dUMFJKZWsxcVJYaE5hbU4zVG1wck5FNXFVWGxPYWtsM1RucE5lVTFxUlhsTlJFVXpUa1JqZVU1NlozcE5hbU0wVGxSWmVrMVVhelJPUkd0M1RrUlZNVTE2VlhkT2VsRTBUbnBCTlU1VVJYZE9WRVV5VG5wTk1VOUVaekpPVkZWM1RsUlZlVTVxWXpST2VsRjZUV3BWZDAxRVRYcE5lbU13VG5wak1VOVVXWGhOYWsxNVRVUlZNVTFVV1RWTlJFRXdUbXBSTUUxRVZURk9SR00xVFdwRk1VNXFSVEZQUkdzd1RWUlZlVTFVVlhkT1ZFMTRUbnBqTUUxRVZUQk5la2t4VDBSSk5VNUVaekZQUkdzMFRWUlJNRTE2UVRSTlZFbDNUbnBOTlUxVVkzaFBSRVV6VG5wUk1FMXFaM2RPYW1zeFRucG5lVTU2VFhkT1JFMTRUa1JyZVU5RVRYbE5hazB4VFdwRk5VNTZUWGRPUkZFd1RucFJkMDE2WnpKT1JFVXhUVVJqTUUxNlJYaFBWR2QzVDFSRk5FNXFXVEZPYWxFeFRtcFJlVTFxVVRCTmFrRXdUa1JCTkU5RVRYZE9WRmwzVDBSck1rMTZVVE5OUkVrMFRVUlZNVTVFVlRCTlZGbDNUbXBOZUUxNldURk5ha2w0VFVSQk1rNTZhM2xPUkVsNlRucG5kMDFVUlROUFJHc3hUbXBuZDA5VWF6TlBWR014VFVSSmVFMTZUVFZOUkVsNFRrUnJNMDlVV1RSTmFtc3hUMVJaZUU1RVZURk5lbEYzVFhwWk1rMTZZekpOVkVVd1RrUm5lVTVxWXpKTmVtY3dUMVJaTUU5VVdYcFBSRWwzVFhwVk1rMXFRVEpOZWtFMVQxUlJNazVxWnpCTlJHdDRUVVJqTTA1NlRUVlBSRmw2VG5wbk5FOUVZekpQUkZsNlRWUlZlVTVFVVhwUFJFbHBXRk40WWtsdE1XaGpNMUpzWTJ3NWVscFhUbmxhV0ZGcFRFTkpNMDVFYTNoTlJGbDRUVlJOZVUxNll6Sk9WRUY1VG5wck0wMTZVWHBPVkVsM1QxUlZlazFFWTNkTmVtTjVUWHBKZWs5VVFUVk5WRmt4VFdwamVVOVVVVFZOZWtGNFRWUnJNazU2VVhsT1ZGa3hUa1JOZDAxcVFYbE5WRmswVFVSQk5FNTZUVE5PUkVFelRYcFplRTlFVVhwT1ZFVXpUMVJqTlU1cVRURk5la0Y0VFZSVmQwMVVhekpQVkZWNVQwUkJOVTVFWXpST2FtYzBUMVJaZDAxRVZYZE5WRUV4VGtSUk5VNXFSVFZPYW10NFRYcFZNMDVVWTNsTmVtc3pUVlJuTTAxNlozcE9SR014VFdwRmVVMXFSVEJOZW1kNFRYcGplazVVVlRCTmVrVTBUMVJKTlUxcVl6VlBSRTB5VG1wQmQwMTZXVEZPZW1kNVQwUlZNRTFVVFhoUFJHY3hUMFJKZUU1cVozbE9la1V5VGxSVk1rNUVZekZQUkUxNlRrUlZlRTU2YXpGT1JFVTBUbnBWZWsxNlRUSk5WRlV3VFZSRk5FMVVZM2hOYWtWM1RVUlJkMDlFU1hsTlZGRjNUV3BGTVU5RVl6Uk5WRTE2VGxSak1FOUVaelJOZWxsM1RVUlJlVTVFYTNsTmFrMHdUbFJaTTAxcVFURk5la2wzVGxSVmQwNTZXVEJPVkdzeVRWUkJNazFVWjNoTlJHZDNUa1JCTVU5VVVYcFBSR014VG5wbk5FNXFSWGRPVkVWM1RucFZOVTFVV1hoUFZGRTFUbnBuZWsxcVp6Sk5hbFYzVGxSSk0wNUVWVEZPVkVWNlQwUlpNazlVWXpOUFJHY3dUMVJOTlU1RVJURk9lbFV3VGxSQk5FMUVVVE5PUkVVelRXcG5NVTFxVlhoT1ZFMHlUVVJSTVU1cVFYbE9SRlYzVDBSVk0wMTZZekZQVkdkM1RtcEJkMDFFVFRST1ZGRXlUbFJqTUU1RVVUTlBWR015VFhwRk1FMTZUVFJPZWxWNlRsUlplVTFFWXpOT1JFVjZUbnBKZDAxVVZYZE9hbGw1VGxSRk5VNVVaekpPUkZVeVQwUkZNMDlVYXpCTmVrMTNUbXBqZWsxVVRYaFBSRWsxVGtSQmVVNUVUVFZOZWxsNVQxUm5OVTFxV1RGTmVsVjRUMVJaTWs1cVozcE9lbWQ2VFhwak5FMTZWVFZPZWswMFRucE5lVTVVU1hwTmVsRjVUa1JWTUU1cVRUSk5hbGswVFhwak0wNTZVVEJOYWxFeVRucFpNMDE2WjNsTmFrbDZUMVJOTlU5VVFUTk9hbU13VDFSWmQwMUVRWGhQUkUxM1QxUlZNazlFVVRKT1ZGa3dUMVJWTTAxRVozbE5WR2N5VGxSWk0wOVVZekZOVkVFMVRVUlpNMDU2V1RST2VtZDRUa1JyZUU5VVFUSlBWRTE2VDFSUmQwOUVhekZOYWxVMFRtcFZNRTU2YXpCT2Vra3dUVVJaZWs5RVRYcE5hbFV5VDFSWk1FNXFhekpPUkZFeVRucGpNRTU2UlRSTmFrRXdUMFJyTlUxRVNUUk5hbGt6VDBSVk1FNXFXVEZOVkd0NVRYcE5OVTlFVVhoT1ZGVTBUbFJyZDAxRVNUVk5lbXQ0VDBSSmFWaFRlR0pKYlRWb1lsZFZhVXhEU1hoTmFra3dUVlJKTVUxVVFUVlBSRVY1VFdwRk5FNUVTWGxPVkdkM1RVUlJlazlVVlRGTlZFMDFUMFJGTkUxRVRYZFBWRUV3VFVSSmVFNUVSVE5OVkd0NFRucFJlVTFVWjNsT1JFMDBUbnBGZWsxVVJYaE9SRUUwVGtSQk1FNVVXVEZPZWxrMVRrUm5NVTVVYXpST1JGRjZUbnBWTWs1Nlp6Vk5lbGswVGtSSmVVMVVSVFJPUkdOM1RrUmpNRTFFWXpGT1JGVXpUa1JuTUUxNmF6Sk5WR3Q0VG1wcmVrOVVVWGxPVkZVd1RsUlpNMDVFVFROTlZFRTFUa1JuTVUxVVVYaE5hbXQzVG5wamVFMXFUVEJPUkZrMVRWUm5kMDFxV1RKTlZHZDVUWHBWTlUxNldYbE9SR3N3VDBSbmVVNTZZekZPVkZsNFRsUmplRTFVUlhsTmFsRXlUVlJaTWs1cVkzZE5ha2swVGxSbmVrOUVTVFZOVkdjMFRrUnJNVTVVWnpOTmFsbDVUWHBOZWsxNlVUSk9SRlY1VG1wak1FMTZRWGRPUkVVd1RVUlZkMDlFU1hkTmVsRXlUbnBuTTA5VVZYbE9ha1V3VDBSQmQwNTZaelZPZWxVelRtcEZlazFVVVROTmVtczBUVlJuZDA1cVozcE5WRTE2VDFSck1rOUVhelJPZW1OM1RrUmplRTlFVVRGTmFtTXdUMFJWZWsxcVVYZFBWRlY2VG1wTmQwNTZhekpPYWxsNFQxUkZNVTFFV1hsTmVsRXpUbnBuTUUxVVp6Qk5lbEV3VFhwbk1FMUVaM2hPVkZsM1QwUk5kMDlFYXpKTmVsbDRUMFJuTUUxRVNUQk9SRkY1VGtSamVrMXFVVFZPVkd0NFQxUk5lVTlVV1hoT1ZGRjNUa1JGTUU1cVVUQk9SRmt4VFdwTmVFOVVUWHBQVkVsNFQwUnJlazFVYXpOTmVsVTBUVlJGTlU1RWEzZE9lbGt5VFhwWk5VOVVTWGhOUkVrMFRtcFplazVVWnpCTlJHczBUbFJOZUU1VVkzcE9hazB6VG5wcmVrOVVaelJPVkZWNlRrUlJNVTU2YXpST1ZHZDVUVVJOTWs1RVFYcE9ha1Y0VFZSUmVVOUVXVEJOZWxrMVRVUk5lVTFVYXpCTlZFa3hUbXBuTVUxNlVYbFBWR042VDFSUmVFMTZVVFZPUkVWM1RucEpNVTFxWnpGT2FsRjRUVlJWTVUxRVl6Tk5lazB5VGxSck1rMXFTWGROZW10NVQwUkJNMDFVU1hwUFJHc3pUbXByZWs5RVFYcE9SRUUwVDFSUk1rNVVRVEZQUkVFd1RucHJNMDFFVVhsTmVsRTFUWHBOTlUxRVdUQlBSRlY0VDBSWk5FNXFWVE5PVkVVMVRucFJORTFVVVhwUFZFMHhUa1JuTWs1RVkzcE5SRWsxVFZSUmVVMTZXVEpPYW1ONVRYcG5lazVVVFhsTlZFa3dUWHBGTVU5VVNUUk5SRWsxVDBSUk1VMTZZM2xOVkZWNVRVUlZlVTU2VlhkTmFrRjRUMFJOTTA1VVl6Tk9WRmt5VFVSak1VOUVXWGxPVkVVeVRtcG5NMDE2VVRSTlZFMHlUa1JGZDA1NmF6Vk5ha2w0VFVSTmVVNTVTbVJNUm5OcFdrZEdNRnBUU1hOSmFsbDRUWHBGZVU1RWF6Uk5SRVV3VGxSVk5VNTZSWGxPUkUwMVRVUkZNMDlFV1ROT2FtYzBUVVJGTWs5RVkzZE9lbGt5VG1wamVFNVVTVEZQVkdNeVRVUk5kMDFVWjNsTlJHdDVUVVJSTUUxcVozaE9hbGwzVDFSamVFNXFhM2RPUkZGNlRXcGpNMDFVVVhoTlJGRjZUbnBaTkU5RVFURk9SRVY0VG1wVmVrNUVXWHBPYWsxNFRVUlpNVTFxVlhkTmFtY3pUbFJuTkUxcVZYbE5lbWN3VDBSVmVVMXFWVEpOVkZWNFRsUkJNVTVFV1hsT1ZHc3lUbXBGZUU5VVp6Uk5lbEY2VFhwQmVFMTZRVEJOUkdjeVQwUlZlRTlFU1hwT2VtczBUbXByTUU5RVRUTk9SRWwzVDFSbk5FNXFRVFJOUkVrMVRYcGpNazVxVlROT2FtZDNUVVJKZWs1NlVYbFBSRlY1VDBSamVrOUVRVE5PZWsweFRXcFZORTVVVFRCT2FrVTFUWHBKTUUxNldYaE5ha0Y0VG5wQk5VMTZWWGhPYWtFMVRVUnJOVTVFV1RKT1JGVjZUbFJSZUU5VVNURk5lbXN6VFhwVmVFNXFVWGxPVkZFMVRucFZNazVxYXpGTlZFRTFUbnBWZWs1cVVUUlBSRkY0VDBSbk5FOVVZekZPZWtFd1RYcFJNRTVVVlhkTmVsazBUbXBSZVU1cVNUSk9hbU13VFZSRk1FOUVRVEZOZWxFelQwUk5ORTVxYTNkTmVrVXdUV3BWTVU1RVNYcE5hazE1VFZSUk1VOUVhekZOUkZVd1RtcEZNVTU2UVhwTlZGa3pUMFJqTTA1cVp6Sk9ha2t5VGxSbmVrOVVVWGhPVkVGNFRsUk5NVTVxU1hwTmVtTXdUMVJuZDA5RVZYcE9hbGsxVFZSVk1VNUVVVFZPVkdkNVQxUkJOVTlVV1RGUFZFMTZUWHBOTWs5VVl6Vk5WRVV6VGxSbk1rMVVUVE5OZWtrd1QxUm5NMDVFYXpOTlZFVjVUV3ByTWs5RVdYaFBWR04zVDBSSmVFMUVVWGhOVkZrMVRsUkpORTVVWXpST2FrRjRUMFJuTlU1cVp6Vk5WRWt3VFdwbk1rNVVRVFZPYWtVeVRWUnJlVTFFVFhkUFJFMTZUVlJGTWs1VWF6Uk5hbU4zVG5wak5VMTZUVEJQVkZsNFRVUnJlazFxUVRWT1ZHc3hUa1JGZDAxNlozaFBWRTB5VDFSUk1VMUVRWGhPZWxGNlRVUkpNazVVV1RGUFZFRXlUWHBOTVU5VVZUTk9la0V3VDBSak1rNVVZekZOUkZGNFRsUm5NMDVVU1ROT1ZGa3pUWHBGTTAxNlZUQk5hbXN6VG1wak5FOVVaM2xOZW1jMVRtcG5NVTE2U1hoTlZHTjVUa1JyTTAxRVNYaE5SRmw1VG5wRmVrOVVZM3BOZWxGM1RsUnJlRTVVVlRGT1JFRTBUMVJyZVU5VVVYbE9lbGw1VG5wUk5FNTZWWGRPZWxsNVRtcEZNMDlVV1hoT1ZFVjVUbXBSZWsxcVozbFBWRUY1VFdwcmVVNTZTWGxPVkdjMFRVUmpNVTVFYTNoTmVrRTBUMFJGZUUxRVNUTk5SR042VFhwSk5VMVVSWHBPUTBwa1dGZ3djMGx0TlhaaWJVNXNTV3B2YVUxNlJUSk5lbGw1VDBSVmVVOVVaekZQVkZrMVRucEZORTFVYTNkT1JHZDRTVzR3UFNKOWZWMTkifX1dfQ"
        let type = InvitationUrlParser.getInvitationType(url: oobInvitation)
        XCTAssertEqual(type, .OOB)

        _ = try await agent.oob.receiveInvitationFromUrl(oobInvitation)
        try await TestHelper.wait(for: expectation, timeout: 5)
    }

    // For two agents behind mediators to connect, message forward is needed.
    func testMessageForward() async throws {
        var aliceConfig = try TestHelper.getBaseConfig(name: "alice")
        aliceConfig.mediatorPickupStrategy = .Implicit
        aliceConfig.mediatorConnectionsInvite = publicMediatorUrl
        let alice = Agent(agentConfig: aliceConfig, agentDelegate: nil)
        agent = alice
        try await alice.initialize()

        var faberConfig = try TestHelper.getBaseConfig(name: "faber")
        faberConfig.mediatorPickupStrategy = .Implicit
        faberConfig.mediatorConnectionsInvite = publicMediatorUrl
        let faber = Agent(agentConfig: faberConfig, agentDelegate: nil)
        try await faber.initialize()

        let (aliceConnection, faberConnection) = try await TestHelper.makeConnection(alice, faber, waitFor: 2)
        XCTAssertEqual(aliceConnection.state, .Complete)
        XCTAssertEqual(faberConnection.state, .Complete)

        // alice will be reset on tearDown
        try await faber.reset()
    }

    // This tests DID exchange using did:peer numAlgo 2
    func testDidExchangeViaMediator() async throws {
        var aliceConfig = try TestHelper.getBaseConfig(name: "alice")
        aliceConfig.mediatorPickupStrategy = .Implicit
        aliceConfig.mediatorConnectionsInvite = publicMediatorUrl
        aliceConfig.mediatorPollingInterval = 1
        let alice = Agent(agentConfig: aliceConfig, agentDelegate: nil)
        agent = alice
        try await alice.initialize()

        var faberConfig = try TestHelper.getBaseConfig(name: "faber")
        faberConfig.mediatorPickupStrategy = .Implicit
        faberConfig.mediatorConnectionsInvite = publicMediatorUrl
        faberConfig.mediatorPollingInterval = 1
        let faber = Agent(agentConfig: faberConfig, agentDelegate: nil)
        try await faber.initialize()

        let outOfBandRecord = try await faber.oob.createInvitation(config: CreateOutOfBandInvitationConfig())
        let invitation = outOfBandRecord.outOfBandInvitation

        alice.agentConfig.preferredHandshakeProtocol = .DidExchange11
        let (_, connection) = try await alice.oob.receiveInvitation(invitation)
        guard let aliceFaberConnection = connection else {
            XCTFail("Connection is nil after receiving oob invitation")
            return
        }
        XCTAssertEqual(aliceFaberConnection.state, .Complete)

        // Wait enough time for faber to process complete message.
        try await Task.sleep(nanoseconds: UInt64(faberConfig.mediatorPollingInterval * 2 * SECOND))

        guard let faberAliceConnection = await faber.connectionService.findByInvitationKey(try invitation.invitationKey()!) else {
            XCTFail("Cannot find connection by invitation key")
            return
        }
        XCTAssertEqual(faberAliceConnection.state, .Complete)

        XCTAssertTrue(TestHelper.isConnectedWith(received: faberAliceConnection, connection: aliceFaberConnection))
        XCTAssertTrue(TestHelper.isConnectedWith(received: aliceFaberConnection, connection: faberAliceConnection))

        // alice will be reset on tearDown
        try await faber.reset()
    }
}
