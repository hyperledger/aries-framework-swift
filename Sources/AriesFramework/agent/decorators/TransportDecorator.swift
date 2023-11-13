
import Foundation
public struct TransportDecorator {
    var returnRoute: String?
    var returnRouteThread: String?
}

extension TransportDecorator: Codable {
    enum CodingKeys: String, CodingKey {
        case returnRoute = "return_route", returnRouteThread = "return_route_thread"
    }
}
