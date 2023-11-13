
import XCTest
@testable import AriesFramework

class OutOfBandServiceTest: XCTestCase {
    var outOfBandService: OutOfBandService!
    var agent: Agent!
    var config: AgentConfig!
    let invitationId = "69212a3a-d068-4f9d-a2dd-4741bca89af3" // invitationId of the MockOutOfBand

    override func setUp() async throws {
        try await super.setUp()

        config = try TestHelper.getBaseConfig(name: "alice")
        agent = Agent(
            agentConfig: config,
            agentDelegate: nil
        )
        try await agent.initialize()
        outOfBandService = agent.outOfBandService
    }

    override func tearDown() async throws {
        try await agent.reset()
        try await super.tearDown()
    }

    func testStateChange() async throws {
        let reuseMessage = HandshakeReuseMessage(parentThreadId: invitationId)
        let json = try JSONEncoder().encode(reuseMessage)
        let messageContext = InboundMessageContext(
            message: reuseMessage,
            plaintextMessage: String(data: json, encoding: .utf8)!,
            connection: TestHelper.getMockConnection(),
            senderVerkey: nil, recipientVerkey: nil)

        var mockOob = try TestHelper.getMockOutOfBand(
            role: OutOfBandRole.Sender,
            state: OutOfBandState.AwaitResponse,
            reusable: true)
        try await agent.outOfBandRepository.save(mockOob)

        class TestDelegate: AgentDelegate {
            let expectation: XCTestExpectation
            init(expectation: XCTestExpectation) {
                self.expectation = expectation
            }
            func onOutOfBandStateChanged(outOfBandRecord: OutOfBandRecord) {
                expectation.fulfill()
            }
        }
        let notCalledExpectation = expectation(description: "state change not called")
        agent.agentDelegate = TestDelegate(expectation: notCalledExpectation)

        _ = try await outOfBandService.processHandshakeReuse(messageContext: messageContext)
        var result = XCTWaiter.wait(for: [notCalledExpectation], timeout: 0.1)
        if result == XCTWaiter.Result.timedOut {
            // onOutOfBandStateChanged not called.
        } else {
            XCTFail("onOutOfBandStateChanged called")
        }

        mockOob = try TestHelper.getMockOutOfBand(
            role: OutOfBandRole.Sender,
            state: OutOfBandState.AwaitResponse,
            reusable: false)
        try await agent.outOfBandRepository.update(mockOob)

        let calledExpectation = expectation(description: "state change called")
        agent.agentDelegate = TestDelegate(expectation: calledExpectation)

        _ = try await outOfBandService.processHandshakeReuse(messageContext: messageContext)
        result = XCTWaiter.wait(for: [calledExpectation], timeout: 0.1)
        if result != XCTWaiter.Result.timedOut {
            // onOutOfBandStateChanged called.
        } else {
            XCTFail("onOutOfBandStateChanged not called")
        }
    }

    func testHandshakeReuse() async throws {
        let reuseMessage = HandshakeReuseMessage(parentThreadId: invitationId)
        let json = try JSONEncoder().encode(reuseMessage)
        let messageContext = InboundMessageContext(
            message: reuseMessage,
            plaintextMessage: String(data: json, encoding: .utf8)!,
            connection: TestHelper.getMockConnection(),
            senderVerkey: nil, recipientVerkey: nil)

        let mockOob = try TestHelper.getMockOutOfBand(
            role: OutOfBandRole.Sender,
            state: OutOfBandState.AwaitResponse,
            reusable: true)
        try await agent.outOfBandRepository.save(mockOob)

        let reuseAcceptedMessage = try await outOfBandService.processHandshakeReuse(messageContext: messageContext)
        XCTAssertEqual(reuseAcceptedMessage.thread?.threadId, reuseMessage.id)
        XCTAssertEqual(reuseAcceptedMessage.thread?.parentThreadId, reuseMessage.thread?.parentThreadId)
    }

    func testStateChangeOnAccept() async throws {
        let reuseAcceptedMessage = HandshakeReuseAcceptedMessage(threadId: "threadId", parentThreadId: invitationId)
        let json = try JSONEncoder().encode(reuseAcceptedMessage)
        let connection = TestHelper.getMockConnection(state: .Complete)
        let messageContext = InboundMessageContext(
            message: reuseAcceptedMessage,
            plaintextMessage: String(data: json, encoding: .utf8)!,
            connection: connection,
            senderVerkey: nil, recipientVerkey: nil)

        let mockOob = try TestHelper.getMockOutOfBand(
            role: OutOfBandRole.Receiver,
            state: OutOfBandState.PrepareResponse,
            reusable: true,
            reuseConnectionId: connection.id)
        try await agent.outOfBandRepository.save(mockOob)

        class TestDelegate: AgentDelegate {
            let expectation: XCTestExpectation
            init(expectation: XCTestExpectation) {
                self.expectation = expectation
            }
            func onOutOfBandStateChanged(outOfBandRecord: OutOfBandRecord) {
                expectation.fulfill()
                XCTAssertEqual(outOfBandRecord.state, OutOfBandState.Done)
            }
        }
        let calledExpectation = expectation(description: "state change called")
        agent.agentDelegate = TestDelegate(expectation: calledExpectation)

        _ = try await outOfBandService.processHandshakeReuseAccepted(messageContext: messageContext)
        let result = XCTWaiter.wait(for: [calledExpectation], timeout: 0.1)
        if result != XCTWaiter.Result.timedOut {
            // onOutOfBandStateChanged called.
        } else {
            XCTFail("onOutOfBandStateChanged not called")
        }
    }
}
