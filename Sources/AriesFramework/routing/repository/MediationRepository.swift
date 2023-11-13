
import Foundation

class MediationRepository: Repository<MediationRecord> {
    func getByConnectionId(_ connectionId: String) async throws -> MediationRecord {
        return try await getSingleByQuery("{\"connectionId\": \"\(connectionId)\"}")
    }

    func getDefault() async throws -> MediationRecord? {
        return try await findSingleByQuery("{}")
    }
}
