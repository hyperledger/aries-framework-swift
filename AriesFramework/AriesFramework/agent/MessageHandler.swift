
import Foundation

public protocol MessageHandler {
    var messageType: String { get }
    func handle(messageContext: InboundMessageContext) async throws -> OutboundMessage?
}
