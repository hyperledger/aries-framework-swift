
import Foundation
import Indy
import os

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

    func recordToInstance(record: WalletRecord) throws -> T {
        var instance = try JSONDecoder().decode(T.self, from: record.value.data(using: .utf8)!)

        instance.id = record.id
        instance.tags = record.tags

        return instance
    }

    public func save(_ record: T) async throws {
        let value = try JSONEncoder().encode(record)
        let tags = record.getTags().toString()
        try await IndyNonSecrets.addRecord(inWallet: wallet.handle!, type: T.type, id: record.id, value: String(data: value, encoding: .utf8), tagsJson: tags)
    }

    public func update(_ record: T) async throws {
        let value = try JSONEncoder().encode(record)
        let tags = record.getTags().toString()
        try await IndyNonSecrets.updateRecordTags(inWallet: wallet.handle!, type: T.type, id: record.id, tagsJson: tags)
        try await IndyNonSecrets.updateRecordValue(inWallet: wallet.handle!, type: T.type, id: record.id, value: String(data: value, encoding: .utf8))
    }

    public func delete(_ record: T) async throws {
        try await IndyNonSecrets.deleteRecord(inWallet: wallet.handle!, type: T.type, id: record.id)
    }

    public func getById(_ id: String) async throws -> T {
        let recordJson = try await IndyNonSecrets.record(fromWallet: wallet.handle!, type: T.type, id: id, optionsJson: DEFAULT_QUERY_OPTIONS)!
        let record = try JSONDecoder().decode(WalletRecord.self, from: recordJson.data(using: .utf8)!)
        return try recordToInstance(record: record)
    }

    public func getAll() async -> [T] {
        return await findByQuery("{}")
    }

    public func findByQuery(_ query: String) async -> [T] {
        do {
            let records = try await search(type: T.type, query: query)
            return try records.map { try recordToInstance(record: $0) }
        } catch {
            logger.debug("Query \(query) failed with error: \(error)")
            return []
        }
    }

    private func search(type: String, query: String, limit: Int = Int.max) async throws -> [WalletRecord] {
        let handle = try await IndyNonSecrets.openSearch(inWallet: wallet.handle!, type: type, queryJson: query, optionsJson: DEFAULT_QUERY_OPTIONS)
        var recordJson: String?
        do {
            recordJson = try await IndyNonSecrets.fetchNextRecords(fromSearch: handle, walletHandle: wallet.handle!, count: limit as NSNumber)
        } catch {
            logger.error("Fetch records failed: \(error.localizedDescription)")
            try await IndyNonSecrets.closeSearch(withHandle: handle)
            throw error
        }

        try await IndyNonSecrets.closeSearch(withHandle: handle)
        let recordList = try JSONDecoder().decode(WalletRecordList.self, from: recordJson!.data(using: .utf8)!)
        return recordList.records ?? []
    }

    public func findById(_ id: String) async throws -> T? {
        do {
            return try await getById(id)
        } catch {
            let err = error as NSError
            if err.code == IndyErrorCode.WalletItemNotFound.rawValue {
                return nil
            }
            throw error
        }
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
