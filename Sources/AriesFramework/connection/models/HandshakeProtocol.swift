
import Foundation

public enum HandshakeProtocol: String, Codable {
    case Connections = "https://didcomm.org/connections/1.0"
    case DidExchange10 = "https://didcomm.org/didexchange/1.0"
    case DidExchange11 = "https://didcomm.org/didexchange/1.1"
}
