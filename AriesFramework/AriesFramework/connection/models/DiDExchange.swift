
import Foundation

public enum DidExchangeRole: String, Codable {
    case Requester = "requester"
    case Responder = "responder"
}

public enum DidExchangeState: String, Codable {
    case Start = "start"
    case InvitationSent = "invitation-sent"
    case InvitationReceived = "invitation-received"
    case RequestSent = "request-sent"
    case RequestReceived = "request-received"
    case ResponseSent = "response-sent"
    case ResponseReceived = "response-received"
    case Abandoned = "abandoned"
    case Completed = "completed"
}
