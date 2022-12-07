
import Foundation

public class ProofRepository: Repository<ProofExchangeRecord> {
    public func getByThreadAndConnectionId(threadId: String, connectionId: String?) async throws -> ProofExchangeRecord {
        if let connectionId = connectionId {
            return try await getSingleByQuery("""
                {"threadId": "\(threadId)",
                "connectionId": "\(connectionId)"}
                """
            )
        } else {
            return try await getSingleByQuery("""
                {"threadId": "\(threadId)"}
                """
            )
        }
    }
}
