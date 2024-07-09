
import Foundation

public class InvitationUrlParser {
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

    public static func parseUrl(_ url: String) async throws -> (OutOfBandInvitation?, ConnectionInvitationMessage?) {
        let type = getInvitationType(url: url)
        var invitation: ConnectionInvitationMessage?
        var outOfBandInvitation: OutOfBandInvitation?
        switch type {
        case .Connection:
            invitation = try ConnectionInvitationMessage.fromUrl(url)
        case .OOB:
            outOfBandInvitation = try OutOfBandInvitation.fromUrl(url)
        default:
            (outOfBandInvitation, invitation) = try await invitationFromShortUrl(url)
        }

        return (outOfBandInvitation, invitation)
    }

    static func invitationFromShortUrl(_ url: String) async throws -> (OutOfBandInvitation?, ConnectionInvitationMessage?) {
        guard let url = URL(string: url) else {
            throw AriesFrameworkError.frameworkError("Invalid url: \(url)")
        }
        let (data, response) = try await URLSession.shared.data(for: URLRequest(url: url))
        if response.mimeType != "application/json" {
            throw AriesFrameworkError.frameworkError("Invalid content-type from short url: \(String(describing: response.mimeType))")
        }

        var invitationJson = String(data: data, encoding: .utf8)!
        invitationJson = OutOfBandInvitation.replaceLegacyDidSovWithNewDidCommPrefix(message: invitationJson)
        let message = try MessageReceiver.decodeAgentMessage(plaintextMessage: invitationJson)
        if message.type == ConnectionInvitationMessage.type {
            let invitation = try JSONDecoder().decode(ConnectionInvitationMessage.self, from: data)
            return (nil, invitation)
        } else if message.type.starts(with: "https://didcomm.org/out-of-band/") {
            let invitation = try OutOfBandInvitation.fromJson(invitationJson)
            return (invitation, nil)
        } else {
            throw AriesFrameworkError.frameworkError("Invalid message type from short url: \(message.type)")
        }
    }
}
