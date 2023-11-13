
import Foundation

public enum InvitationType: String {
    case Connection = "ConnectionInvitation"
    case OOB = "OutOfBandInvitation"
    case Unknown = "Unknown"
}

public enum OutOfBandRole: String, Codable {
    case Sender = "sender"
    case Receiver = "receiver"
}

public enum OutOfBandState: String, Codable {
    case Initial = "initial"
    case AwaitResponse = "await-response"
    case PrepareResponse = "prepare-response"
    case Done = "done"
}

public struct CreateOutOfBandInvitationConfig {
    public var label: String?
    public var alias: String?
    public var imageUrl: String?
    public var goalCode: String?
    public var goal: String?
    public var handshake: Bool?
    public var messages: [AgentMessage]?
    public var multiUseInvitation: Bool?
    public var autoAcceptConnection: Bool?
    public var routing: Routing?
}

public struct ReceiveOutOfBandInvitationConfig {
    public var label: String?
    public var alias: String?
    public var imageUrl: String?
    public var autoAcceptInvitation: Bool?
    public var autoAcceptConnection: Bool?
    public var reuseConnection: Bool?
    public var routing: Routing?
}
