
import Foundation

public class OutOfBandService {
    let agent: Agent
    let outOfBandRepository: OutOfBandRepository
    let handshakeReuseWaiter = AsyncWaiter()

    init(agent: Agent) {
        self.agent = agent
        self.outOfBandRepository = agent.outOfBandRepository
    }

    public func processHandshakeReuse(messageContext: InboundMessageContext) async throws -> HandshakeReuseAcceptedMessage {
        let decoder = JSONDecoder()
        let reuseMessage = try decoder.decode(HandshakeReuseMessage.self, from: Data(messageContext.plaintextMessage.utf8))

        guard let parentThreadId = reuseMessage.thread?.parentThreadId else {
            throw AriesFrameworkError.frameworkError("handshake-reuse message must have a parent thread id")
        }

        guard var outOfBandRecord = try await findByInvitationId(parentThreadId) else {
            throw AriesFrameworkError.frameworkError("No out of band record found for handshake-reuse message with parentThreadId: \(parentThreadId)")
        }

        try outOfBandRecord.assertRole(OutOfBandRole.Sender)
        try outOfBandRecord.assertState(OutOfBandState.AwaitResponse)

        if !outOfBandRecord.reusable {
            try await updateState(outOfBandRecord: &outOfBandRecord, newState: .Done)
        }

        return HandshakeReuseAcceptedMessage(threadId: reuseMessage.threadId, parentThreadId: parentThreadId)
    }

    public func processHandshakeReuseAccepted(messageContext: InboundMessageContext) async throws {
        let decoder = JSONDecoder()
        let reuseAcceptedMessage = try decoder.decode(HandshakeReuseAcceptedMessage.self, from: Data(messageContext.plaintextMessage.utf8))

        guard let parentThreadId = reuseAcceptedMessage.thread?.parentThreadId else {
            throw AriesFrameworkError.frameworkError("handshake-reuse-accepted message must have a parent thread id")
        }

        guard var outOfBandRecord = try await findByInvitationId(parentThreadId) else {
            throw AriesFrameworkError.frameworkError("No out of band record found for handshake-reuse-accepted message  with parentThreadId: \(parentThreadId)")
        }

        try outOfBandRecord.assertRole(OutOfBandRole.Receiver)
        try outOfBandRecord.assertState(OutOfBandState.PrepareResponse)

        let reusedConnection = try messageContext.assertReadyConnection()
        if outOfBandRecord.reuseConnectionId != reusedConnection.id {
            throw AriesFrameworkError.frameworkError("handshake-reuse-accepted is not in response to a handshake-reuse message.")
        }

        try await updateState(outOfBandRecord: &outOfBandRecord, newState: .Done)
    }

    public func createHandShakeReuse(outOfBandRecord: OutOfBandRecord, connectionRecord: ConnectionRecord) async throws -> HandshakeReuseMessage {
        let reuseMessage = HandshakeReuseMessage(parentThreadId: outOfBandRecord.outOfBandInvitation.id)

        var updateRecord = outOfBandRecord
        updateRecord.reuseConnectionId = connectionRecord.id
        try await outOfBandRepository.update(updateRecord)

        return reuseMessage
    }

    public func save(outOfBandRecord: OutOfBandRecord) async throws {
        try await outOfBandRepository.save(outOfBandRecord)
    }

    func updateState(outOfBandRecord: inout OutOfBandRecord, newState: OutOfBandState) async throws {
        outOfBandRecord.state = newState
        try await outOfBandRepository.update(outOfBandRecord)
        if newState == .Done {
            finishHandshakeReuseWaiter()
        }

        agent.agentDelegate?.onOutOfBandStateChanged(outOfBandRecord: outOfBandRecord)
    }

    public func findById(_ outOfBandRecordId: String) async throws -> OutOfBandRecord? {
        return try await outOfBandRepository.findById(outOfBandRecordId)
    }

    public func getById(_ outOfBandRecordId: String) async throws -> OutOfBandRecord {
        return try await outOfBandRepository.getById(outOfBandRecordId)
    }

    public func findByInvitationId(_ invitationId: String) async throws -> OutOfBandRecord? {
        return try await outOfBandRepository.findByInvitationId(invitationId)
    }

    public func findAllByInvitationKey(_ invitationKey: String) async -> [OutOfBandRecord] {
        return await outOfBandRepository.findAllByInvitationKey(invitationKey)
    }

    public func findByFingerprint(_ fingerprint: String) async throws -> OutOfBandRecord? {
        return try await outOfBandRepository.findByFingerprint(fingerprint)
    }

    public func getAll() async -> [OutOfBandRecord] {
        return await outOfBandRepository.getAll()
    }

    public func deleteById(_ outOfBandId: String) async throws {
        let outOfBandRecord = try await getById(outOfBandId)
        try await outOfBandRepository.delete(outOfBandRecord)
    }

    func waitForHandshakeReuse() async throws -> Bool {
        return try await handshakeReuseWaiter.wait()
    }

    private func finishHandshakeReuseWaiter() {
        handshakeReuseWaiter.finish()
    }
}
