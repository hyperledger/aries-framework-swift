
import Foundation

public class RevocationRegistryRepository: Repository<RevocationRegistryRecord> {
    public func findByCredDefId(_ credDefId: String) async throws -> RevocationRegistryRecord? {
        return try await findSingleByQuery("{\"credDefId\": \"\(credDefId)\"}")
    }

    // We don't need lock here because this is for testing only.
    public func incrementRegistryIndex(credDefId: String) async throws -> Int {
        var record = try await getSingleByQuery("{\"credDefId\": \"\(credDefId)\"}")
        record.registryIndex += 1
        try await update(record)
        return record.registryIndex
    }
}
