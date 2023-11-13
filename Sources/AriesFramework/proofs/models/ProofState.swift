
import Foundation

public enum ProofState: String, Codable {
    case ProposalSent = "proposal-sent"
    case ProposalReceived = "proposal-received"
    case RequestSent = "request-sent"
    case RequestReceived = "request-received"
    case PresentationSent = "presentation-sent"
    case PresentationReceived = "presentation-received"
    case Declined = "declined"
    case Done = "done"
}
