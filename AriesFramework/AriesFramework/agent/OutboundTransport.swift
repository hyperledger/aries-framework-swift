
import Foundation

public protocol OutboundTransport {
    func sendPackage(_ package: OutboundPackage) async throws
}
