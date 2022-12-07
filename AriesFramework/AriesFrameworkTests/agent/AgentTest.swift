
import XCTest
@testable import AriesFramework
import Indy

class AgentTest: XCTestCase {
    let mediatorInvitationUrl = "http://localhost:3001/invitation"
    let agentInvitationUrl = "http://localhost:3002/invitation"
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
        config.mediatorConnectionsInvite = "https://public.mediator.indiciotech.io?c_i=eyJAdHlwZSI6ICJkaWQ6c292OkJ6Q2JzTlloTXJqSGlxWkRUVUFTSGc7c3BlYy9jb25uZWN0aW9ucy8xLjAvaW52aXRhdGlvbiIsICJAaWQiOiAiMDVlYzM5NDItYTEyOS00YWE3LWEzZDQtYTJmNDgwYzNjZThhIiwgInNlcnZpY2VFbmRwb2ludCI6ICJodHRwczovL3B1YmxpYy5tZWRpYXRvci5pbmRpY2lvdGVjaC5pbyIsICJyZWNpcGllbnRLZXlzIjogWyJDc2dIQVpxSktuWlRmc3h0MmRIR3JjN3U2M3ljeFlEZ25RdEZMeFhpeDIzYiJdLCAibGFiZWwiOiAiSW5kaWNpbyBQdWJsaWMgTWVkaWF0b3IifQ=="
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
        config.mediatorConnectionsInvite = "http://localhost:3001/invitation?oob=eyJAdHlwZSI6Imh0dHBzOi8vZGlkY29tbS5vcmcvb3V0LW9mLWJhbmQvMS4xL2ludml0YXRpb24iLCJAaWQiOiI2YmRiNTc5Mi0zMWQ4LTQyOGMtYTNmYy01MjA1OTUwNDE5NWQiLCJsYWJlbCI6IkFyaWVzIEZyYW1ld29yayBKYXZhU2NyaXB0IE1lZGlhdG9yIiwiYWNjZXB0IjpbImRpZGNvbW0vYWlwMSIsImRpZGNvbW0vYWlwMjtlbnY9cmZjMTkiXSwiaGFuZHNoYWtlX3Byb3RvY29scyI6WyJodHRwczovL2RpZGNvbW0ub3JnL2RpZGV4Y2hhbmdlLzEuMCIsImh0dHBzOi8vZGlkY29tbS5vcmcvY29ubmVjdGlvbnMvMS4wIl0sInNlcnZpY2VzIjpbeyJpZCI6IiNpbmxpbmUtMCIsInNlcnZpY2VFbmRwb2ludCI6Imh0dHA6Ly9sb2NhbGhvc3Q6MzAwMSIsInR5cGUiOiJkaWQtY29tbXVuaWNhdGlvbiIsInJlY2lwaWVudEtleXMiOlsiZGlkOmtleTp6Nk1rbm4xNldHOEg4M1gyZnlDenR5cENhTThwMTRjVlVCSjNUdDlFdFRGTkh2NDMiXSwicm91dGluZ0tleXMiOltdfSx7ImlkIjoiI2lubGluZS0xIiwic2VydmljZUVuZHBvaW50Ijoid3M6Ly9sb2NhbGhvc3Q6MzAwMSIsInR5cGUiOiJkaWQtY29tbXVuaWNhdGlvbiIsInJlY2lwaWVudEtleXMiOlsiZGlkOmtleTp6Nk1rbm4xNldHOEg4M1gyZnlDenR5cENhTThwMTRjVlVCSjNUdDlFdFRGTkh2NDMiXSwicm91dGluZ0tleXMiOltdfV19"

        let expectation = TestHelper.expectation(description: "credential received")
        let testDelegate = CredentialDelegate(expectation: expectation)
        agent = Agent(agentConfig: config, agentDelegate: testDelegate)
        try await agent.initialize()

        let faberInvitationUrl = "http://localhost:9001?oob=eyJAdHlwZSI6Imh0dHBzOi8vZGlkY29tbS5vcmcvb3V0LW9mLWJhbmQvMS4xL2ludml0YXRpb24iLCJAaWQiOiI0N2Q3MTFiNS03OWMyLTQ2ZjctOWMxYy0xYjViMTllN2YyYmEiLCJsYWJlbCI6ImZhYmVyIiwiYWNjZXB0IjpbImRpZGNvbW0vYWlwMSIsImRpZGNvbW0vYWlwMjtlbnY9cmZjMTkiXSwiaGFuZHNoYWtlX3Byb3RvY29scyI6WyJodHRwczovL2RpZGNvbW0ub3JnL2RpZGV4Y2hhbmdlLzEuMCIsImh0dHBzOi8vZGlkY29tbS5vcmcvY29ubmVjdGlvbnMvMS4wIl0sInNlcnZpY2VzIjpbeyJpZCI6IiNpbmxpbmUtMCIsInNlcnZpY2VFbmRwb2ludCI6Imh0dHA6Ly9sb2NhbGhvc3Q6OTAwMSIsInR5cGUiOiJkaWQtY29tbXVuaWNhdGlvbiIsInJlY2lwaWVudEtleXMiOlsiZGlkOmtleTp6Nk1rZzE3dk13QW8zTTFhWkZGcTRHREx0MlVxWnNrY1h1S1dXZnZ4NHNMenNDY3IiXSwicm91dGluZ0tleXMiOltdfV19"
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
    // This test fails for now because AFJ has a bug.
    func testReceiveCredentialThroughOOB() async throws {
        let config = try TestHelper.getBcovinConfig(name: "alice")
        let expectation = TestHelper.expectation(description: "credential received")
        let testDelegate = CredentialDelegate(expectation: expectation)
        agent = Agent(agentConfig: config, agentDelegate: testDelegate)
        try await agent.initialize()

        let oobInvitation = "http://example.com?oob=eyJAdHlwZSI6Imh0dHBzOi8vZGlkY29tbS5vcmcvb3V0LW9mLWJhbmQvMS4xL2ludml0YXRpb24iLCJAaWQiOiIxZWE2YzQ0Zi02YjFhLTRhM2QtYTg3Mi1lOWQ0NGY2OTMxMjEiLCJsYWJlbCI6IkZhYmVyIENvbGxlZ2UiLCJnb2FsX2NvZGUiOiJpc3N1ZS12YyIsImdvYWwiOiJUbyBpc3N1ZSBhIGNyZWRlbnRpYWwiLCJhY2NlcHQiOlsiZGlkY29tbS9haXAxIiwiZGlkY29tbS9haXAyO2Vudj1yZmMxOSJdLCJoYW5kc2hha2VfcHJvdG9jb2xzIjpbImh0dHBzOi8vZGlkY29tbS5vcmcvZGlkZXhjaGFuZ2UvMS4wIiwiaHR0cHM6Ly9kaWRjb21tLm9yZy9jb25uZWN0aW9ucy8xLjAiXSwic2VydmljZXMiOlt7ImlkIjoiI2lubGluZS0wIiwic2VydmljZUVuZHBvaW50IjoiaHR0cDovL2xvY2FsaG9zdDozMDAwIiwidHlwZSI6ImRpZC1jb21tdW5pY2F0aW9uIiwicmVjaXBpZW50S2V5cyI6WyJkaWQ6a2V5Ono2TWtlc1pjbkdMOUVMMktxSlBmbWV0dGhlVGdoNjk1SHFWTlhGNG42dVVyMXNtQiJdLCJyb3V0aW5nS2V5cyI6W119XSwicmVxdWVzdHN-YXR0YWNoIjpbeyJAaWQiOiJmN2IxM2ZiZi1lMjZjLTQxZmUtYTA2Yy0zMGVjMDQ0ZjIzODMiLCJtaW1lLXR5cGUiOiJhcHBsaWNhdGlvbi9qc29uIiwiZGF0YSI6eyJiYXNlNjQiOiJleUpBZEhsd1pTSTZJbWgwZEhCek9pOHZaR2xrWTI5dGJTNXZjbWN2YVhOemRXVXRZM0psWkdWdWRHbGhiQzh4TGpBdmIyWm1aWEl0WTNKbFpHVnVkR2xoYkNJc0lrQnBaQ0k2SWpGak1EQmtZelUxTFRNM1lXUXROR0kwWlMwNE0yRXhMVEpqWVRBeU1tVmxZbUpoTnlJc0ltTnlaV1JsYm5ScFlXeGZjSEpsZG1sbGR5STZleUpBZEhsd1pTSTZJbWgwZEhCek9pOHZaR2xrWTI5dGJTNXZjbWN2YVhOemRXVXRZM0psWkdWdWRHbGhiQzh4TGpBdlkzSmxaR1Z1ZEdsaGJDMXdjbVYyYVdWM0lpd2lZWFIwY21saWRYUmxjeUk2VzNzaWJXbHRaUzEwZVhCbElqb2lkR1Y0ZEM5d2JHRnBiaUlzSW01aGJXVWlPaUp1WVcxbElpd2lkbUZzZFdVaU9pSkJiR2xqWlNKOUxIc2liV2x0WlMxMGVYQmxJam9pZEdWNGRDOXdiR0ZwYmlJc0ltNWhiV1VpT2lKaFoyVWlMQ0oyWVd4MVpTSTZJakl3SW4xZGZTd2liMlptWlhKemZtRjBkR0ZqYUNJNlczc2lRR2xrSWpvaWJHbGlhVzVrZVMxamNtVmtMVzltWm1WeUxUQWlMQ0p0YVcxbExYUjVjR1VpT2lKaGNIQnNhV05oZEdsdmJpOXFjMjl1SWl3aVpHRjBZU0k2ZXlKaVlYTmxOalFpT2lKbGVVcDZXVEpvYkdKWFJtWmhWMUZwVDJsSk0xTXpWa1ZXU0VKU1lVUk9TRk5xWkVoalJGcHlVbGhLZDFZeldrNVBha2syWXpKT2IxcFhNV2hNVjBwdFRtcEdhazVIVlhsTVYxSm9UWHBuZEU1RVVteFpVekExVGxkV2JVeFhSbWhOYW1ScVdsUkpNRTlVVlRCWmFtOTRUR3BCYVV4RFNtcGpiVlpyV0RKU2JGcHNPWEJhUTBrMlNXcGtUR1JWVWxWalJrWnZUVEJrUzA0d1pIZE9iWFJHWTI1Q1dHUnJNRFpOZW5CRVZFUnZNVTlVV1RWTmFrVTJXa2RXYlZsWVZuTmtRMGx6U1cxMGJHVldPV3BpTTBwNVdsZE9NR0p0Vm5wak1UbDNZMjA1ZGxwcFNUWmxlVXBxU1dwdmFVNXFVWHBPVkVsNlRucEZNRTlFVlROTmFra3dUbFJCZWs1cVJYbE9hazB4VFVSSmVFNXFaelJQUkdNMVQxUmpNazlFWnpGTlJFMTRUV3BGTkUxRVRURk5hbXQ0VFVSbmVFMUVZM3BPYW1kNVRWUm5NRTFFWnpCT1ZHTXhUbXBaZUU1cWF6UlBSRVZwVEVOS05HVnNPV3BaV0VGcFQybEplRTE2VFRKTmFrbDZUa1JCTlUxNlJUTk9hbFY1VFVSSk5VMUVTVEpQVkd0M1RXcGpNazVxUlRKUFZHTXpUVlJOTTAxNlNYcE9WRUUxVDBSQk5FOVVTVEJPZW1NeFQwUlpNRTVxVlhsUFJFMDFUMFJOZDA1NlNUQlBSR3N6VDBSSk0wMTZRVFJPVkUweFRtcFJlVTVxUlhsTmFrMDFUVVJyTUU5RVVUQk9WRUUxVFZSck1FOVVUVE5OZW1kNVRucHJNRTFVVFROTmFrMTZUbFJqTTAxRVozZFBWRVY2VFVSbk1FNVVVVFJOVkdjd1RYcE5NazVFVVhoT2Ftc3hUVVJaTUUxVVp6Uk9lbGwzVDBSRmVVNXFUVEJOUkZGNFRVUnJlRTVFU1RGT1ZFRTBUa1JqTTAxRVdURk9WRkUxVFVSSmQwNVVZM3BPZW1zelRWUnJlVTFFVlROT2Fra3hUMVJGZDA1NlVYaFBSRTAwVDFScmVrNTZZekJPZWtsNFRXcEJNMDlVVVhsUFZHczBUWHBqTVU1VVdYbE5lbFYzVDFSbmVrOUVUVEJPZWsxNFRWUk5NMDVxV1hoT1ZHc3hUWHBaTlUxVVZURk5WR3N4VFZSUmVVOUVhekZPVkdONlRrUkpNRTE2UlhwTmFsbDVUa1JKZUU1Nlp6Tk5ha1Y0VFVSQk1rNUVaelZOUkZsNlRtcEZlVTU2YXpGTlZFRjNUbnBOTkUxVVRUSlBSRTE2VFVSbmVrNTZSWGRPYWtWNlRXcFpNMDlFWXpGUFJHZDVUbXBqTVUxcWEzaE5hbEUxVFhwSmQwNUVXVEpQUkZWM1QxUm5NMDVFWTNoT2VsRTBUMFJCTVUxVVZUTk5hbFY2VGtSck5VNTZUWHBOUkZWM1RsUkJNRTlFVVhoTmFrVTFUWHBWZVU1NlJYaE9SRTAwVGtSck1rNXFhM2ROVkVsNlRVUlJNRTU2WXpSUFZGa3lUbFJKTWs1RVVUSlBWRWswVDFSWk1FMUVhelZQVkVsM1RucE5lVTVxVVROUFJHTjVUMFJOTVUxcVNUVlBWRVV6VG1wSmVrOVVXVFZPVkZGNlQxUkJORTVFUlRWT1ZFazBUbFJWZVU1RVozaE5la1V3VGtSSk0wMUVRWHBPYWswMVRXcEJkMDFVUVROT1ZHTXhUWHBqZVU1NlZUQlBSRVY1VG5wSk5FOVVUWGxOYWtFelRXcGpNMDVVWTNwTlJHZDVUVlJuZVU1RVl6Rk5lbFV5VFVSWk1FMTZXVEpPZWxVelRYcFpORTVVWTNsT2Vtc3lUWHBCZWs1VVFYcE5la0V5VFVSWk1rMTZXVEZPYWxrd1RXcFpORTVFVFhkT1JGVTFUWHBuTVU5RVFUTk5WRTB3VFVSVmVrMTZVVEJPUkZVd1RWUlplVTU2UVRKT2FsRjRUVVJKZUU1NlFYaE5hbWMxVGxSck0wNUVSWGhOYWxFMFQwUlpNVTFFVFROTmVrVjNUVVJGTTA1cVRUTlBSRWwzVFhwbk1VMUVhekZPVkVreVRtcFJORTE2WXpKTmFtZDVUVVJaZVU5RVdUSk5SRWwzVGxSQmQwMVVWVFJPVkZFd1RYcGpkMDE2U1RGUFZGbDRUMFJqTWs1RVdUTk9WR2N6VDFSVmFVeERTalJqYkRscVdWaEJhVTlzZEdKSmJUVm9ZbGRWYVV4RFNURk5lbWQzVFZSUk0wNUVSVEpPZWxFeVRXcHJORTFxVlRGUFZGVXhUbFJGTWsxcVVUQk9SR2MxVDFSVmVFMVVUWHBPVkZsNVRWUk5NRTFVVlRWUFJHdDRUbnBuTVUxVWF6Vk9hbWN5VG1wak5FNVVWVEJQVkdzeFRsUlJNazFxVFRCTlZGVXpUbnBOTTA1RVp6Vk5ha2w0VG5wak0wNUVSWGxQUkVrMFRWUm5lRTVxUlRST2FsVXlUMVJGTTA5VVNURk5lbU0wVGtSak0wNTZaM2hPYWxFd1QxUlZlazU2UVRST1ZFbDVUbnBWZVU1cVFYcE5lbU40VFZSak1FNUVaM3BQUkVVMVQwUlpNVTlFU1hoUFZFMTRUbnBSTkU1RVdURk5hbU0xVGxSTk1FOVVhek5OVkVVMFQxUkJNVTFVU1RWT2VrVXlUbnBuTlUxVVp6Uk9hbFV5VDBSbk1VNVVTWGRPYW1ONlRYcG5lVTFFWnpWUFJHTTFUWHBqZVUxcVJUUk5SRlV4VFVSRmVFMVVXWGxOVkdNeVRtcEJlVTVxV1hoTlZFMHhUMVJOTUU1RVkzaE9la1Y2VFdwak0wMXFTVEpOUkVVeFRtcG5NRTFxUVRCT1ZFRjVUbXBqTkUxNldYcFBSRTAxVGxSbmVrNVVZM2RPYWtsNVRtcFZNMDFxWXpGTlJFVjRUWHBuZVU1VWF6Tk5lbFUwVG1wSmQwMUVWVEJPVkdkNVRXcEpORTVFVlhsT1JFazBUMFJSTkU5RVZURlBSRWsxVDBScmQwMXFhekZQVkd0NlRWUkpNRTVVUlROTlZFVXlUMVJGTVU1VVRUTk9WRTE1VFVSSmVVMVVSVE5OZWtsM1RtcFpNVTFFUlhoT2FrRXdUbFJqTVU1VVp6RlBWRkUwVGtSUk1rMUVUVEJPZWtGNFRtcE5kMDU2WjNoUFJGbDZUbXBWZUU1RVZUUk9SRkV5VG5wTk1VOUVVWGxPYWxFelRVUk5NRTVVVVhkTmVsVjNUWHBWZUU5VWF6Vk5hbFUwVG5wSk5VNTZVWGhQUkZrelRtcFJlazE2U1ROTmVtTXhUMVJqZWsxVWF6Tk9hbXN6VFdwTk0wNUVRVFZQVkVWM1RWUlJOVTE2U1RWUFJHY3hUa1JWTTA5VVp6SlBSRTB5VGxSRk1VNUVhM2xOZWxreVRWUkZOVTFxVFhsTmVtTjZUbXBSTkUxVVVYaE5lazB4VFhwbmVrNTZUVEZPVkVVMVRVUk5kMDlVVFhkT1ZFVjRUV3BOZUU5RVNUUk5lbEV6VFVSWk1VNVVVWGRQVkVsNFQxUlpORTVFVVhkTlZGbDNUVlJSZWs5VVNUSk9lbU42VFZSUk1FNXFXVFJPYW1jeFRsUmpNVTFxWnpKT2FtZDVUWHBOTWsxVWF6Qk9ha1V3VDFSQk1VOVVUWGRPZWtGNVRWUmplazlVU1hkT1ZGVTBUMVJqTTAxRVZYaE9hbGsxVG5wWk5FNUVZM2ROVkZGNVRtcFplVTVxWnpCT1ZFMDFUMVJOTWsxNll6Uk9hazB5VG1wcmVrNUVWVEpOUkVFelQxUm5ORTVVYTNwUFZHYzFUbFJCTlUxRWF6Qk5WRTB5VG1wTmVVOVVSVEpPVkZWM1RWUlJkMDVxVVdsWVUzaGlTVzFHYmxwVFNYTkphbU0xVGtSWk1VNVVaM3BPYWtFeVRXcFZORTFFUVRGTlZGVjZUV3BWTTAxVWF6Vk9ha0V3VGtScmQwOVVVVEZPUkdNMFRVUkplRTFFU1hkT1JFVTBUbFJSZVU5RVJUUk9hbU15VFdwbk0wNVVSVFZQVkVWNlRtcEZlRTFFU1hkTmFsRjZUbXBqTTA5VVJUVk5la1Y0VG1wRmVVNVVRVEZOVkVVd1RucFpOVTE2U1ROTlZHdDRUMFJqZWs1NmEzcE9WRVY2VDBSVmVVOVVhM2hPZWxrelRVUk5lazFFVlRST1ZHTjRUbnBuTUU5VVZUVk9SRmt3VFhwck0wMVVRVEpPYW1NelRrUnJORTVxV1hoTmVsVXpUVVJCTVUxVVNUVk9WRVV4VFVSak1FNXFSWGxPYWxrMFRYcEpNazE2V1RST2FsbDNUbFJCZDA5VVp6Qk5SRUY0VGtSTk1FOUVSVFZOZW1zMFRtcG5lazU2VlRST2VsRXhUMFJWTTAxNlRUUlBWRVY0VFdwVk5FMTZWVEZOYWxFeVRsUmpNRTVVWTNwTmFsVTBUbnBWTWs1RVRUTlBSRmwzVFdwTmVrNTZTVEJPYWxsNVRrUkJOVTFFV1hkTlJGRjNUVlJqTWs5VVVYcE5lbWQ0VFdwbk5FMUVZekJOYW1zd1RWUlJkMDVVV1hoT1ZGVXpUVlJKZWsxVVp6Rk9hbGt6VFhwUk1FMXFXVE5PVkZGNFRtcG5NVTU2VFhwTlZHTjZUMFJqZWs1cVVURk9lbGt6VFdwUmVrNUVWWGRPUkdONVQwUk5NazlFUVRWT2VrRTFUbXBKTlU1NlJUUk9ha1UxVFVSWk0wMVVSVFJPZWtWNFRsUnJkMDFVVVRCUFJFRXlUbXBSTUU1cVkzcE9hbEV5VDFSak1FMVVaM3BOVkd0NFRrUlZlRTFFVVhsUFZFMDFUbFJKZVU1cVFURlBSRmt3VGxSRk1rMTZUVE5QVkdzeVRVUk5lRTU2UlhsT2VtdDVUMVJCZWs1NlFUUk5SRUY1VDBSQk1rNXFhekZPUkVrd1RXcEZlVTVFUVRGT1ZHY3pUbnBWTVUxRVNUUk5SRkV6VFhwRmVVMVVTWHBOZW1jMFQwUk5lazFFWnpCT1ZFMHlUVVJuZWs1cVp6Rk9WRTB3VG5wTmVFOVVRVEJOZWxVMFRrUnJNRTlFV1hsTmFsazBUVVJqZUU1RVozaE9WRUV6VFVSRk5VNVVRVFJPUkZGM1RrUkJOVTVxUVRGUFZFRXhUWHBaTlU1cVNUUk5SRUUxVFVSck5VMVVhelJPVkdjMVRVUkZlVTFVUlRGUFJHYzBUMVJWZDAxRVp6QlBSRVV3VDFSWmVVMVVaM2RPUkVsNVRtcFpNRTVxVFRSUFZFVTBUMVJCTTA1cVZUSk9SRVY2VG1wVk1FOUVaM2hOYW1kNVQxUkZOVTU2V1hoTmFrbDVUa1JSZWsxRVFUQlBWR3MxVGtSbk1VMXFRVFJOUkdjeVQxUkJORTE2UVRGT2Fsa3lUbnBaZVU1NlZUQlBSRWwzVFhwVk5FOVVaM2hOZWswelRucHJkMDU2V1hsTlZFMHlUV3BOTTA5VVl6Uk9lbEY1VGxSWmVrMUVTVE5PUkdjMFRsUk5NMDFFVVROT2VVcGtURVp6YVdKWFJucGtSMVo1V0ROT2JGa3pTbXhrUTBselNXcFpNRTE2U1hkT2VtdDRUbFJuTUU5VVRUQk5WRmw2VGtScmVVMXFZM3BOUkd0NlQwUmpNMDFFWTNwTlZFa3hUa1JOTlUxNll6Qk9SR3N4VGtSVk0wOVVWWGhPVkVrd1RVUkpNazlFU1RWT2Fra3dUMVJaTlUxNll6VlBWRkUwVFZSRk1FNVVSVFZQUkVFelRrUk5lRTlFUlRGTmVrRXlUVVJCTkU1VVl6Vk5SRVV5VFhwQmQwMTZXVE5OZW1zMFRucFZOVTlFVVhsT2VrMTNUV3ByTUUxcVVURlBWRmw2VG5wRmQwNXFaelZOVkZFeFQwUnJlRTVxVFRWT2FtTjNUVlJyTVUxVVFYaE9hbU40VG1wQk1rMUVhM3BQUkVFeFRXcEJORTFFWjNsT2VrRXhUVlJaZWsxNlNYaE5SRkV5VG1wbmVrOVVTWHBPVkVsM1RtcEZNVTVxVlRWTmFtTTFUbFJOTWs1cVZUQk5ha0V4VDFSUk1FOUVSVEZPVkZGNVQxUlJNRTU2YXpSUFJHczBUVlJKTTA5RWF6Uk5SRmw1VFVSck0wMXFaekJOUkZGNFQxUm5lRTVFWXpWT1ZHYzBUVlJOTkUxRVFUTk5ha0YzVG5wVk1VMUVaM3BOVkd0NlQxUkJNMDFxVVhsT2VsRXhUa1JyTkUxVWEzcE9WRTB4VG5wak1rNTZTVFJQUkdjd1RucFplazFFYTNoUFZGVjZUa1JyTTAxRVp6Sk5lbFUwVFVSTk5VNVVXWHBOYWtWNlRXcEJlazFFUlROT2FrMDFUMFJWZUUxRVVYaE5WRTE0VFhwQk1FNUVWVEJPUkdzelRVUk5lazlVUVhkUFZGRjNUa1JqTWsxcVFUVk5WRTE2VGxSbk1rNUVWWGxOUkdzeFRYcHJkMDlFVVRCUFJFVXpUa1JOZVUxcWF6Sk9WRUV6VDBSUmVVMVVRVFZOZW1zMFRWUlJNVTVVU1RKUFZGa3lUWHBCZUUxVVZUTk5hbFUwVG5wQk5VNVVXVE5PVkdzMVRXcFZlazVFU1RST2Fsa3pUMFJaTVUxRVRUQk9ha0Y0VG5wck0wMVVUWHBOVkVsNFRXcFJNVTVFYXpWUFJFVjNUMVJSTlU1NlFUSk5la1V3VG5wRmVVMTZhM2hQVkdzeFRYcFJNMDFxWnpST2FrRTBUMFJCZDA5VVZYaE9lbWMwVFVSWmQwOVVVWHBOYWxrelQwUkpNMDVVVlRCT1ZGVjRUbXBGTlUxVVFUTlBSR3N3VFVSWk5VNUVXWHBPZWtVeFQwUnJlRTlVVVROT1ZGRjRUMFJKTVU1VVVUVk9WR2Q0VGxSSmVVMTZZelJOUkZFMVRucEpORTFFVVRGTlZFVTFUMVJaTTA5RVRYcE9WRWt5VFdwTk1VNVVWVFZOVkZWNVQwUmpkMDVFVlhwUFJGVXpUbnBGTTAxRVJYaE9ha0UwVGxSUmVrOUVXWGhOUkZVMVRWUlplRTFFU1RKT2Ftc3hUWHBKTkU5VVp6Qk5SR2MwVFVSQk5FMUVRWGROYWtGM1RYcFJNMDFxUlROT1ZHTXlUWHBSTkUxVVNYcE5hazB5VFhwTk0wNVVhM2xPVkVreVRWUlZlVTFVUlhwT1JHTXhUbnBGZDA5VVRUUk5lbGswU1d3eFpHWlRkMmxpYlRsMVdUSlZhVTlwU1RGUFJHTjVUWHByZWs1RVZYcE9lbFV6VGtSQk5FOVVTVEZPZW1NeFRWUkJhV1pSUFQwaWZYMWRmUT09In19XX0"
        let type = OutOfBandInvitation.getInvitationType(url: oobInvitation)
        XCTAssertEqual(type, .OOB)

        _ = try await agent.oob.receiveInvitationFromUrl(oobInvitation)
        try await TestHelper.wait(for: expectation, timeout: 5)
    }
}
