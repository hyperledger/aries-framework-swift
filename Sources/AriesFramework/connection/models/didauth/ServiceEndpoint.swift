
import Foundation

public struct ServiceEndpoint: Codable {
    var uri: String
    var accept: [String]
    var routingKeys: [String]
}
