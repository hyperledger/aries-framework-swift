
import XCTest
import Criollo
@testable import AriesFramework

class AATHTest: XCTestCase {
    func testAATH() async throws {
        let testHarnessConfig = TestHarnessConfig.shared
        try await testHarnessConfig.prepareAgent()

        let backchannel = CRHTTPServer()
        backchannel.add("/agent/command/agent", controller: AgentController.self)
        backchannel.add("/agent/command/connection", controller: ConnectionController.self)
        backchannel.add("/agent/command/credential", controller: CredentialController.self)
        backchannel.add("/agent/command/issue-credential", controller: IssueCredentialController.self)
        backchannel.add("/agent/command/out-of-band", controller: OutOfBandController.self)
        backchannel.add("/agent/command/proof", controller: PresentProofController.self)
        backchannel.get("/agent/command/status") { (req, res, next) in
            res.send(["status": "active"])
        }

        print("starting backchannel on port \(testHarnessConfig.backchannelPort)")
        var serverError: NSError?
        backchannel.startListening(&serverError, portNumber: UInt(testHarnessConfig.backchannelPort))

        print("starting agent inbound on port \(testHarnessConfig.agentPort)")
        let agentInbound = CRHTTPServer()
        agentInbound.add("/", controller: AgentInboundController.self)
        agentInbound.startListening(&serverError, portNumber: UInt(testHarnessConfig.agentPort))

        try await Task.sleep(nanoseconds: UInt64(60 * 20 * SECOND))
    }
}
