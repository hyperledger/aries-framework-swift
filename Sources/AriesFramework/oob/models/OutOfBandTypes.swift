
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
    public init(label: String? = nil, alias: String? = nil, imageUrl: String? = nil, goalCode: String? = nil, goal: String? = nil, handshake: Bool? = nil, messages: [AgentMessage]? = nil, multiUseInvitation: Bool? = nil, autoAcceptConnection: Bool? = nil, routing: Routing? = nil) {
        self.label = label
        self.alias = alias
        self.imageUrl = imageUrl
        self.goalCode = goalCode
        self.goal = goal
        self.handshake = handshake
        self.messages = messages
        self.multiUseInvitation = multiUseInvitation
        self.autoAcceptConnection = autoAcceptConnection
        self.routing = routing
    }
    
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
    public init(label: String? = nil, alias: String? = nil, imageUrl: String? = nil, autoAcceptInvitation: Bool? = nil, autoAcceptConnection: Bool? = nil, reuseConnection: Bool? = nil, routing: Routing? = nil) {
        self.label = label
        self.alias = alias
        self.imageUrl = imageUrl
        self.autoAcceptInvitation = autoAcceptInvitation
        self.autoAcceptConnection = autoAcceptConnection
        self.reuseConnection = reuseConnection
        self.routing = routing
    }
    
    public var label: String?
    public var alias: String?
    public var imageUrl: String?
    public var autoAcceptInvitation: Bool?
    public var autoAcceptConnection: Bool?
    public var reuseConnection: Bool?
    public var routing: Routing?
}
