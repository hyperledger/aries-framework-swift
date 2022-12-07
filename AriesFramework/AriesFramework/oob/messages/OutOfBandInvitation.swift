
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
        if let encodedInvitation = encodedInvitation, let data = Data(base64Encoded: encodedInvitation.base64urlToBase64()) {
            let invitationJson = try JSONDecoder().decode(OutOfBandInvitation.self, from: data)
            return invitationJson
        } else {
            throw AriesFrameworkError.frameworkError("InvitationUrl is invalid. It needs to contain one, and only one, of the following parameters; `oob`")
        }
    }

    public static func fromJson(_ json: String) throws -> OutOfBandInvitation {
        return try JSONDecoder().decode(OutOfBandInvitation.self, from: json.data(using: .utf8)!)
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

    public static func getInvitationType(url: String) -> InvitationType {
        let parsedUrl = URLComponents(string: url)
        if parsedUrl?.queryItems?.first(where: { $0.name == "oob" }) != nil {
            return .OOB
        } else if parsedUrl?.queryItems?.first(where: { $0.name == "c_i" || $0.name == "c_m" }) != nil {
            return .Connection
        } else {
            return .Unknown
        }
    }
}
