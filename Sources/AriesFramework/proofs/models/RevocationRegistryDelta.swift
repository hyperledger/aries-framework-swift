
import Foundation

public struct RevocationRegistryDelta: Codable {
    public let ver: String
    public let value: RevocationRegistryDeltaValue

    public func toJsonString() -> String {
        let encoder = JSONEncoder()
        // swiftlint:disable:next force_try
        let data = try! encoder.encode(self)
        return String(data: data, encoding: .utf8)!
    }
}

public struct RevocationRegistryDeltaValue: Codable {
    public let prevAccum: String?
    public let accum: String
    public let issued: [UInt32]?
    public let revoked: [UInt32]?
}
