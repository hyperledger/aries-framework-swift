
import XCTest
import Indy
@testable import AriesFramework

class RepositotyTest: XCTestCase {
    var agent: Agent!
    var repository: Repository<TestRecord>!

    override func setUp() async throws {
        try await super.setUp()

        let config = try TestHelper.getBaseConfig(name: "alice")
        agent = Agent(agentConfig: config, agentDelegate: nil)
        repository = Repository<TestRecord>(agent: agent)
        try await agent.initialize()
    }

    override func tearDown() async throws {
        try await agent.reset()
        try await super.tearDown()
    }

    func insertRecord(id: String? = nil, tags: Tags? = nil) async -> TestRecord {
        let record = TestRecord(id: id, tags: tags ?? ["myTag": "foobar"], foo: "bar")
        try? await repository.save(record)
        return record
    }

    func testSave() async throws {
        let record = await insertRecord(id: "test-id")
        do {
            try await repository.save(record)
            XCTFail("RecordDuplicateError expected")
        } catch {
            let err = error as NSError
            XCTAssertEqual(err.code, IndyErrorCode.WalletItemAlreadyExists.rawValue)
        }
    }

    func testSaveAndGet() async throws {
        let record = await insertRecord()
        let record2 = try await repository.getById(record.id)
        XCTAssertEqual(record.id, record2.id)
        XCTAssertEqual(record.createdAt, record2.createdAt)
        XCTAssertEqual(record.tags, record2.tags)
        XCTAssertEqual(record.foo, record2.foo)

        do {
            _ = try await repository.getById("not-found")
            XCTFail("RecordNotFoundError expected")
        } catch {
            let err = error as NSError
            XCTAssertEqual(err.code, IndyErrorCode.WalletItemNotFound.rawValue)
        }
    }

    func testUpdate() async throws {
        var record = TestRecord(id: "test-id", tags: ["myTag": "foobar"], foo: "test")
        do {
            try await repository.update(record)
            XCTFail("RecordNotFoundError expected")
        } catch {
            let err = error as NSError
            XCTAssertEqual(err.code, IndyErrorCode.WalletItemNotFound.rawValue)
        }

        try await repository.save(record)
        var tags = record.getTags()
        tags["foo"] = "bar"
        record.tags = tags
        record.foo = "baz"
        try await repository.update(record)
        let record2 = try await repository.getById(record.id)

        XCTAssertEqual(record.tags, record2.tags)
        XCTAssertEqual(record.foo, record2.foo)
    }

    func testDelete() async throws {
        let record = await insertRecord()
        try await repository.delete(record)
        do {
            _ = try await repository.getById(record.id)
            XCTFail("RecordNotFoundError expected")
        } catch {
            let err = error as NSError
            XCTAssertEqual(err.code, IndyErrorCode.WalletItemNotFound.rawValue)
        }
    }

    func testGetAll() async throws {
        let record1 = await insertRecord()
        let record2 = await insertRecord()
        let records = try await repository.getAll()
        XCTAssertEqual(records.count, 2)
        XCTAssertTrue(records.contains(where: { $0.id == record1.id }))
        XCTAssertTrue(records.contains(where: { $0.id == record2.id }))
    }

    func testFindByQuery() async throws {
        let expectedRecord = await insertRecord(tags: ["myTag": "foobar"])
        _ = await insertRecord(tags: ["myTag": "notfoobar"])
        let records = try await repository.findByQuery("{\"myTag\": \"foobar\"}")
        XCTAssertEqual(records.count, 1)
        XCTAssertEqual(records[0].id, expectedRecord.id)

        let emptyRecords = try await repository.findByQuery("{\"myTag\": \"notfound\"}")
        XCTAssertEqual(emptyRecords.count, 0)
    }

    func testFindById() async throws {
        let record = await insertRecord()
        let record2 = try await repository.findById(record.id)!
        XCTAssertEqual(record.id, record2.id)
        XCTAssertEqual(record.createdAt, record2.createdAt)
        XCTAssertEqual(record.tags, record2.tags)
        XCTAssertEqual(record.foo, record2.foo)

        do {
            let record = try await repository.findById("not-found")
            XCTAssertNil(record)
        } catch {
            XCTFail("findById() should not throw")
        }
    }

    func testFindSingByQuery() async throws {
        let expectedRecord = await insertRecord(tags: ["myTag": "foobar"])
        let record = try await repository.findSingleByQuery("{\"myTag\": \"foobar\"}")!
        XCTAssertEqual(record.id, expectedRecord.id)
        let record2 = try await repository.findSingleByQuery("{\"myTag\": \"notfound\"}")
        XCTAssertNil(record2)

        _ = await insertRecord(tags: ["myTag": "foobar"]) // Insert duplicate tags
        do {
            _ = try await repository.findSingleByQuery("{\"myTag\": \"foobar\"}")
            XCTFail("Should throw error when more than one record found")
        } catch AriesFrameworkError.recordDuplicateError(_) {
            // expected
        } catch {
            XCTFail("Should not throw unknown error")
        }
    }

    func testGetSingleByQuery() async throws {
        let expectedRecord = await insertRecord(tags: ["myTag": "foobar"])
        let record = try await repository.getSingleByQuery("{\"myTag\": \"foobar\"}")
        XCTAssertEqual(record.id, expectedRecord.id)

        do {
            _ = try await repository.getSingleByQuery("{\"myTag\": \"notfound\"}")
            XCTFail("Should throw error when not found")
        } catch AriesFrameworkError.recordNotFoundError(_) {
            // expected
        } catch {
            XCTFail("Should not throw unknown error")
        }
    }
}
