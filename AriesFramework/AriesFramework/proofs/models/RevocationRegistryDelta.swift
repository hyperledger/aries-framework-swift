
import Foundation

public struct RevocationRegistryDelta: Decodable {
    public let version: String
    public let value: RevocationRegistryDeltaValue
}

public struct RevocationRegistryDeltaValue: Decodable {
    public let prevAccum: String
    public let accum: String
    public let issued: [String]?
    public let revoked: [String]?
}
