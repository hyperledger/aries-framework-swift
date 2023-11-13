
import Foundation

public class CredentialDefinitionRepository: Repository<CredentialDefinitionRecord> {
    public func getByCredDefId(_ credDefId: String) async throws -> CredentialDefinitionRecord {
        return try await getSingleByQuery("{\"credDefId\": \"\(credDefId)\"}")
    }
}
