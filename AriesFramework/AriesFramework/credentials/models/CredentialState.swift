
import Foundation

public enum CredentialState: String, Codable {
    case ProposalSent = "proposal-sent"
    case ProposalReceived = "proposal-received"
    case OfferSent = "offer-sent"
    case OfferReceived = "offer-received"
    case Declined = "declined"
    case RequestSent = "request-sent"
    case RequestReceived = "request-received"
    case CredentialIssued = "credential-issued"
    case CredentialReceived = "credential-received"
    case Done = "done"
}
