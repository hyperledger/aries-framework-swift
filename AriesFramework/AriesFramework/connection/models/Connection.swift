
import Foundation

public enum ConnectionRole: String, Codable {
    case Inviter = "inviter"
    case Invitee = "invitee"
}

public enum ConnectionState: String, Codable {
    case Invited = "invited"
    case Requested = "requested"
    case Responded = "responded"
    case Complete = "complete"
}

public struct Connection: Codable {
    let did: String
    let didDoc: DidDoc?

    enum CodingKeys: String, CodingKey {
        case did = "DID"
        case didDoc = "DIDDoc"
    }
}
