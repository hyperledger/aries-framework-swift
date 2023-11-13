
import Foundation

public struct RevocationRegistryDelta: Decodable {
    public let ver: String
    public let value: RevocationRegistryDeltaValue
}

public struct RevocationRegistryDeltaValue: Decodable {
    public let prevAccum: String?
    public let accum: String
    public let issued: [UInt32]?
    public let revoked: [UInt32]?
}

public struct RevocationRegistry: Decodable {
    public let accum: String
}
