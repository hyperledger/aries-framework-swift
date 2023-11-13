
import Foundation
import os
import Askar

struct WalletRecord: Codable {
    let id: String
    let type: String
    let value: String
    let tags: Tags
}

struct WalletRecordList: Codable {
    let records: [WalletRecord]?
}

public class Repository<T: BaseRecord & Codable> {
    let wallet: Wallet
    let agent: Agent
    let logger = Logger(subsystem: "AriesFramework", category: "Repository")

    let DEFAULT_QUERY_OPTIONS = """
    {
        "retrieveType": true,
        "retrieveTags": true
    }
    """

    init(agent: Agent) {
        self.wallet = agent.wallet
        self.agent = agent
    }

    func recordToInstance(record: AskarEntry) throws -> T {
        var instance = try JSONDecoder().decode(T.self, from: Data(record.value()))

        instance.id = record.name()
        instance.tags = record.tags()

        return instance
    }

    public func save(_ record: T) async throws {
        let value = try JSONEncoder().encode(record)
        let tags = record.getTags().toString()
        try await wallet.session!.update(operation: .insert, category: T.type, name: record.id, value: value, tags: tags, expiryMs: nil)
    }

    public func update(_ record: T) async throws {
        let value = try JSONEncoder().encode(record)
        let tags = record.getTags().toString()
        try await wallet.session!.update(operation: .replace, category: T.type, name: record.id, value: value, tags: tags, expiryMs: nil)
    }

    public func delete(_ record: T) async throws {
        try await wallet.session!.update(operation: .remove, category: T.type, name: record.id, value: Data(), tags: nil, expiryMs: nil)
    }

    public func getById(_ id: String) async throws -> T {
        guard let record = try await wallet.session!.fetch(category: T.type, name: id, forUpdate: false) else {
            throw AriesFrameworkError.recordNotFoundError("Record not found for id \(id)")
        }
        return try recordToInstance(record: record)
    }

    public func getAll() async -> [T] {
        return await findByQuery("{}")
    }

    public func findByQuery(_ query: String) async -> [T] {
        do {
            let scan = try await wallet.store!.scan(profile: nil, category: T.type, tagFilter: query, offset: nil, limit: nil)
            let records = try await scan.fetchAll()
            return try records.map { try recordToInstance(record: $0) }
        } catch {
            logger.debug("Query \(query) failed with error: \(error)")
            return []
        }
    }

    public func findById(_ id: String) async throws -> T? {
        guard let record = try await wallet.session!.fetch(category: T.type, name: id, forUpdate: false) else {
            return nil
        }
        return try recordToInstance(record: record)
    }

    public func findSingleByQuery(_ query: String) async throws -> T? {
        let records = await findByQuery(query)
        if records.count == 1 {
            return records[0]
        } else if records.count == 0 {
            return nil
        } else {
            throw AriesFrameworkError.recordDuplicateError("Multiple records found for query \(query)")
        }
    }

    public func getSingleByQuery(_ query: String) async throws -> T {
        let record = try await findSingleByQuery(query)
        if record != nil {
            return record!
        } else {
            throw AriesFrameworkError.recordNotFoundError("Record not found for query \(query)")
        }
    }
}
