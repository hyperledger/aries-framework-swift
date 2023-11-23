
import Foundation

public struct VersionedRevocationRegistryDelta: Codable {
    public let ver: String
    public let value: RevocationRegistryDelta
}

public struct RevocationRegistryDelta: Codable {
    public let prevAccum: String?
    public let accum: String
    public let issued: [Int]?
    public let revoked: [Int]?

    public func toJsonString() -> String {
        let encoder = JSONEncoder()
        // swiftlint:disable:next force_try
        let data = try! encoder.encode(self)
        return String(data: data, encoding: .utf8)!
    }

    public func toVersionedJson() -> String {
        let versioned = VersionedRevocationRegistryDelta(ver: "1.0", value: self)
        let encoder = JSONEncoder()
        // swiftlint:disable:next force_try
        let data = try! encoder.encode(versioned)
        return String(data: data, encoding: .utf8)!
    }
}
