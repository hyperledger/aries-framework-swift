
import Foundation

public class OutOfBandInvitation: AgentMessage {
    public static var type: String = "https://didcomm.org/out-of-band/1.1/invitation"
    var label: String
    var goalCode: String?
    var goal: String?
    var accept: [String]?
    var handshakeProtocols: [HandshakeProtocol]?
    var requests: [Attachment]?
    var services: [OutOfBandDidCommService]
    var imageUrl: String?

    private enum CodingKeys: String, CodingKey {
        case label, goalCode = "goal_code", goal, accept, handshakeProtocols = "handshake_protocols", requests = "requests~attach", services, imageUrl
    }

    public init(id: String, label: String, goalCode: String? = nil, goal: String? = nil, accept: [String]? = nil, handshakeProtocols: [HandshakeProtocol]? = nil, requests: [Attachment]? = nil, services: [OutOfBandDidCommService] = [], imageUrl: String? = nil) {
        self.label = label
        self.goalCode = goalCode
        self.goal = goal
        self.accept = accept
        self.handshakeProtocols = handshakeProtocols
        self.requests = requests
        self.services = services
        self.imageUrl = imageUrl
        super.init(id: id, type: OutOfBandInvitation.type)
    }

    public required init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        label = try values.decode(String.self, forKey: .label)
        goalCode = try values.decodeIfPresent(String.self, forKey: .goalCode)
        goal = try values.decodeIfPresent(String.self, forKey: .goal)
        accept = try values.decodeIfPresent([String].self, forKey: .accept)
        handshakeProtocols = try values.decodeIfPresent([HandshakeProtocol].self, forKey: .handshakeProtocols)
        requests = try values.decodeIfPresent([Attachment].self, forKey: .requests)
        services = try values.decode([OutOfBandDidCommService].self, forKey: .services)
        if services.count == 0 {
            throw AriesFrameworkError.frameworkError("Decoding out-of-band invitation failed: no services found")
        }
        imageUrl = try values.decodeIfPresent(String.self, forKey: .imageUrl)
        try super.init(from: decoder)
    }

    public override func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(label, forKey: .label)
        try container.encodeIfPresent(goalCode, forKey: .goalCode)
        try container.encodeIfPresent(goal, forKey: .goal)
        try container.encodeIfPresent(accept, forKey: .accept)
        try container.encodeIfPresent(handshakeProtocols, forKey: .handshakeProtocols)
        try container.encodeIfPresent(requests, forKey: .requests)
        try container.encode(services, forKey: .services)
        try container.encodeIfPresent(imageUrl, forKey: .imageUrl)
        try super.encode(to: encoder)
    }

    public func addRequest(message: AgentMessage) throws {
        if self.requests == nil {
            self.requests = []
        }
        let requestAttachment = Attachment(
            id: OutOfBandInvitation.generateId(),
            mimetype: "application/json",
            data: AttachmentData(base64: try JSONEncoder().encode(message).base64EncodedString()))
        self.requests?.append(requestAttachment)
    }

    public func getRequests() throws -> [String] {
        return try self.requests?.map({ (request) -> String in
            return try request.getDataAsString()
        }) ?? []
    }

    public func toUrl(domain: String) throws -> String {
        let invitationJson = try JSONEncoder().encode(self).base64EncodedString()
        let invitationUrl = "\(domain)?oob=\(invitationJson)"
        return invitationUrl
    }

    public static func fromUrl(_ invitationUrl: String) throws -> OutOfBandInvitation {
        let parsedUrl = URLComponents(string: invitationUrl)
        let encodedInvitation = parsedUrl?.queryItems?.first(where: { $0.name == "oob" })?.value
        if let encodedInvitation = encodedInvitation,
           let data = Data(base64Encoded: encodedInvitation.base64urlToBase64()),
           let message = String(data: data, encoding: .utf8) {
            var replaced = replaceLegacyDidSovWithNewDidCommPrefix(message: message)
            replaced = try serializeJsonAttatchments(message: replaced)
            return try JSONDecoder().decode(OutOfBandInvitation.self, from: replaced.data(using: .utf8)!)
        } else {
            throw AriesFrameworkError.frameworkError("InvitationUrl is invalid. It needs to contain one, and only one, of the following parameters; `oob`")
        }
    }

    public static func fromJson(_ json: String) throws -> OutOfBandInvitation {
        // ACA-Py may use the legacy did:sov: prefix, especially in the handshake_protocols field.
        var message = replaceLegacyDidSovWithNewDidCommPrefix(message: json)

        message = try serializeJsonAttatchments(message: message)
        return try JSONDecoder().decode(OutOfBandInvitation.self, from: message.data(using: .utf8)!)
    }

    public func fingerprints() throws -> [String] {
        return try self.services
            .map({
                if case .oobDidDocument(let service) = $0 {
                    return service.recipientKeys
                } else {
                    return []
                }
            })
            .reduce([], +)
            .map({ (recipientKeys) -> String in
                return try DIDParser.getMethodId(did: recipientKeys)
            })
    }

    public func invitationKey() throws -> String? {
        let fingerprints = try self.fingerprints()
        if fingerprints.count == 0 {
            return nil
        }

        return try DIDParser.ConvertFingerprintToVerkey(fingerprint: fingerprints[0])
    }

    public static func replaceLegacyDidSovWithNewDidCommPrefix(message: String) -> String {
        let didSovPrefix = "did:sov:BzCbsNYhMrjHiqZDTUASHg;spec"
        let didCommPrefix = "https://didcomm.org"

        return message.replacingOccurrences(of: didSovPrefix, with: didCommPrefix)
    }

    static func serializeJsonAttatchments(message: String) throws -> String {
        guard var invitation = try JSONSerialization.jsonObject(with: message.data(using: .utf8)!, options: []) as? [String: Any] else {
            throw AriesFrameworkError.frameworkError("Invitation is not a valid json")
        }
        guard let type = invitation["@type"] as? String, type.starts(with: "https://didcomm.org/out-of-band/") else {
            throw AriesFrameworkError.frameworkError("Invitation is not an out-of-band invitation. Type is \(invitation["@type"] ?? "nil")")
        }

        let attachments = invitation["requests~attach"] as? [[String: Any]] ?? []
        var serializedRequests: [[String: Any]] = []
        for attachment in attachments {
            if let data = attachment["data"] as? [String: Any], let json = data["json"] as? [String: Any] {
                var attachment = attachment
                var data = data
                let serialized = try JSONSerialization.data(withJSONObject: json, options: [])
                data["json"] = String(data: serialized, encoding: .utf8)
                attachment["data"] = data
                serializedRequests.append(attachment)
            } else {
                serializedRequests.append(attachment)
            }
        }

        invitation["requests~attach"] = serializedRequests
        let serialized = try JSONSerialization.data(withJSONObject: invitation, options: [])
        if let serializedMessage = String(data: serialized, encoding: .utf8) {
            return serializedMessage
        } else {
            throw AriesFrameworkError.frameworkError("Failed to convert invitation message data to string.")
        }
    }
}
