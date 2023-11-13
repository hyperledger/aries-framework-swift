import Foundation

public class CredentialRepository: Repository<CredentialRecord> {
    public func getByCredentialId(_ credentialId: String) async throws -> CredentialRecord {
        return try await getSingleByQuery("{\"credentialId\": \"\(credentialId)\"}")
    }
}
