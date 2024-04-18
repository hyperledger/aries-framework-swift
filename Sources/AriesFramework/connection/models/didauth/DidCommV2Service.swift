
import Foundation

public struct DidCommV2Service: Codable {
    static var type: String = "DIDCommMessaging"
    var type: String = DidCommV2Service.type
    var id: String
    var serviceEndpoint: ServiceEndpoint

    public struct ServiceEndpoint: Codable {
        var uri: String
        var routingKeys: [String]?
        var accept: [String]?
    }
}
