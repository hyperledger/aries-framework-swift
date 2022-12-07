
import Foundation

public class ConnectionInvitationMessage: AgentMessage {
    var label: String
    var imageUrl: String?
    var did: String?
    var recipientKeys: [String]?
    var serviceEndpoint: String?
    var routingKeys: [String]?
    public static var type: String = "https://didcomm.org/connections/1.0/invitation"

    private enum CodingKeys: String, CodingKey {
        case label, imageUrl, did, recipientKeys, serviceEndpoint, routingKeys
    }

    public init(id: String? = nil, label: String, imageUrl: String? = nil, did: String? = nil, recipientKeys: [String]? = nil, serviceEndpoint: String? = nil, routingKeys: [String]? = nil) {
        self.label = label
        self.imageUrl = imageUrl
        self.did = did
        self.recipientKeys = recipientKeys
        self.serviceEndpoint = serviceEndpoint
        self.routingKeys = routingKeys
        super.init(id: id, type: ConnectionInvitationMessage.type)
    }

    public required init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        label = try values.decode(String.self, forKey: .label)
        imageUrl = try values.decodeIfPresent(String.self, forKey: .imageUrl)
        did = try values.decodeIfPresent(String.self, forKey: .did)
        recipientKeys = try values.decodeIfPresent([String].self, forKey: .recipientKeys)
        serviceEndpoint = try values.decodeIfPresent(String.self, forKey: .serviceEndpoint)
        routingKeys = try values.decodeIfPresent([String].self, forKey: .routingKeys)

        if (did == nil) && (recipientKeys == nil || recipientKeys?.count == 0 || serviceEndpoint == nil) {
            throw AriesFrameworkError.frameworkError("Both did and inline keys / endpoint are missing")
        }

        try super.init(from: decoder)
    }

    public override func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(label, forKey: .label)
        try container.encodeIfPresent(imageUrl, forKey: .imageUrl)
        try container.encodeIfPresent(did, forKey: .did)
        try container.encodeIfPresent(recipientKeys, forKey: .recipientKeys)
        try container.encodeIfPresent(serviceEndpoint, forKey: .serviceEndpoint)
        try container.encodeIfPresent(routingKeys, forKey: .routingKeys)
        try super.encode(to: encoder)
    }

    public static func fromUrl(_ invitationUrl: String) throws -> ConnectionInvitationMessage {
        let queryItems = URLComponents(string: invitationUrl)?.queryItems
        let encodedInvitation = queryItems?.first(where: { $0.name == "c_i" || $0.name == "d_m" })?.value
        if let encodedInvitation = encodedInvitation,
           let data = Data(base64Encoded: encodedInvitation.base64urlToBase64(), options: []) {
            return try JSONDecoder().decode(ConnectionInvitationMessage.self, from: data)
        }
        throw AriesFrameworkError.frameworkError("InvitationUrl is invalid. It needs to contain one, and only one, of the following parameters; `c_i` or `d_m`")
    }

    public func toUrl(domain: String) throws -> String {
        let invitationJson = try JSONEncoder().encode(self)
        let encodedInvitation = invitationJson.base64EncodedString().base64ToBase64url()
        return "\(domain)?c_i=\(encodedInvitation)"
    }
}
