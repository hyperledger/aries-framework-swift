
import Foundation

public struct RevocationInterval {
    public let from: Int?
    public let to: Int?
}

extension RevocationInterval: Codable {
    private enum CodingKeys: String, CodingKey {
        case from, to
    }
}
