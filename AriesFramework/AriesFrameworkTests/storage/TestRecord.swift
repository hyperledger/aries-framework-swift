
import Foundation
@testable import AriesFramework

struct TestRecord: BaseRecord {
    var id: String
    var createdAt: Date
    var tags: Tags?
    var foo: String

    public static let type = "TestRecord"
    var type: String {
        return TestRecord.type
    }
}

extension TestRecord: Codable {
    enum CodingKeys: String, CodingKey {
        case id, createdAt, tags, foo
    }

    init(id: String? = nil, createdAt: Date? = nil, tags: Tags? = nil, foo: String) {
        self.id = id ?? UUID().uuidString
        self.createdAt = createdAt ?? Date()
        self.tags = tags ?? Tags()
        self.foo = foo
    }

    func getTags() -> Tags {
        return self.tags ?? [:]
    }
}
