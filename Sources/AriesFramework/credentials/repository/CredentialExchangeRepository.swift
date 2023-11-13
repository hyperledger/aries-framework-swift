
import Foundation

public class CredentialExchangeRepository: Repository<CredentialExchangeRecord> {
    public func findByThreadAndConnectionId(threadId: String, connectionId: String?) async throws -> CredentialExchangeRecord? {
        if let connectionId = connectionId {
            return try await findSingleByQuery("""
                {"threadId": "\(threadId)",
                "connectionId": "\(connectionId)"}
                """
            )
        } else {
            return try await findSingleByQuery("""
                {"threadId": "\(threadId)"}
                """
            )
        }
    }

    public func getByThreadAndConnectionId(threadId: String, connectionId: String?) async throws -> CredentialExchangeRecord {
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
