
import Foundation
public struct ThreadDecorator {
    var threadId: String?
    var parentThreadId: String?
    var senderOrder: Int?
    var receivedOrders: [String: Int]?
}

extension ThreadDecorator: Codable {
    enum CodingKeys: String, CodingKey {
        case threadId = "thid", parentThreadId = "pthid", senderOrder = "sender_order", receivedOrders = "received_orders"
    }
}
