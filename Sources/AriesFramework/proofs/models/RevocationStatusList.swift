import Foundation

public struct RevocationStatusList {
    public let issuerId: String
    public let currentAccumulator: String
    public let revRegDefId: String
    public let revocationList: [UInt32]
    public let timestamp: Int
}

extension RevocationStatusList: Codable {
    public func toString() throws -> String {
        let data = try JSONEncoder().encode(self)
        return String(data: data, encoding: .utf8)!
    }
}
