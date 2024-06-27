
import Foundation

public protocol InboundTransport {
    func start() async throws
    func stop() async throws
}
