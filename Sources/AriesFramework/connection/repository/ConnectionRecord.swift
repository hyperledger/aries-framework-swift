
import Foundation

public struct ConnectionRecord: BaseRecord {
    public var id: String
    public var createdAt: Date
    var updatedAt: Date?
    public var tags: Tags?

    public var state: ConnectionState
    public var role: ConnectionRole

    var didDoc: DidDoc
    var did: String
    var verkey: String

    var theirDidDoc: DidDoc?
    var theirDid: String?
    public var theirLabel: String?

    var invitation: ConnectionInvitationMessage?
    var outOfBandInvitation: OutOfBandInvitation?
    public var alias: String?
    var autoAcceptConnection: Bool?
    var imageUrl: String?
    var multiUseInvitation: Bool

    var threadId: String?
    var mediatorId: String?
    var errorMessage: String?

    public static let type = "ConnectionRecord"
}

extension ConnectionRecord: Codable {
    enum CodingKeys: String, CodingKey {
        case id, createdAt, updatedAt, state, role, didDoc, did, verkey, theirDidDoc, theirDid, theirLabel, invitation, outOfBandInvitation, alias, autoAcceptConnection, imageUrl, multiUseInvitation, threadId, mediatorId, errorMessage
    }

    init(
        tags: Tags? = nil,
        state: ConnectionState,
        role: ConnectionRole,
        didDoc: DidDoc,
        did: String,
        verkey: String,
        theirDidDoc: DidDoc? = nil,
        theirDid: String? = nil,
        theirLabel: String? = nil,
        invitation: ConnectionInvitationMessage? = nil,
        outOfBandInvitation: OutOfBandInvitation? = nil,
        alias: String? = nil,
        autoAcceptConnection: Bool? = nil,
        imageUrl: String? = nil,
        multiUseInvitation: Bool,
        threadId: String? = nil,
        mediatorId: String? = nil,
        errorMessage: String? = nil) {

        self.id = UUID().uuidString
        self.createdAt = Date()
        self.tags = tags

        self.state = state
        self.role = role

        self.didDoc = didDoc
        self.did = did
        self.verkey = verkey

        self.theirDidDoc = theirDidDoc
        self.theirDid = theirDid
        self.theirLabel = theirLabel

        self.invitation = invitation
        self.outOfBandInvitation = outOfBandInvitation
        self.alias = alias
        self.autoAcceptConnection = autoAcceptConnection
        self.imageUrl = imageUrl
        self.multiUseInvitation = multiUseInvitation

        self.threadId = threadId
        self.mediatorId = mediatorId
        self.errorMessage = errorMessage
    }

    public func getTags() -> Tags {
        var tags = self.tags ?? [:]

        tags["state"] = self.state.rawValue
        tags["role"] = self.role.rawValue

        if let invitationKey = self.invitation?.recipientKeys?[0] {
            tags["invitationKey"] = invitationKey
        } else if let invitationKey = try? self.outOfBandInvitation?.invitationKey() {
            tags["invitationKey"] = invitationKey
        }

        tags["threadId"] = self.threadId
        tags["verkey"] = self.verkey
        tags["theirKey"] = self.theirKey()
        tags["mediatorId"] = self.mediatorId
        tags["did"] = self.did
        tags["theirDid"] = self.theirDid

        return tags
    }

    func myKey() -> String? {
        guard let service = didDoc.didCommServices().first else {
            return nil
        }

        return service.recipientKeys.first
    }

    func theirKey() -> String? {
        guard let service = theirDidDoc?.didCommServices().first else {
            return nil
        }

        return service.recipientKeys.first
    }

    func isReady() -> Bool {
        return [ConnectionState.Responded, ConnectionState.Complete].contains(state)
    }

    func assertReady() throws {
        if !isReady() {
            throw AriesFrameworkError.frameworkError("Connection record is not ready to be used. Expected \(ConnectionState.Responded) or \(ConnectionState.Complete), found invalid state \(state)")
        }
    }

    func assertState(_ expectedStates: ConnectionState...) throws {
        if !expectedStates.contains(state) {
            throw AriesFrameworkError.frameworkError("Connection record is in invalid state \(state). Valid states are: \(expectedStates.map { $0.rawValue }.joined(separator: ", ")).")
        }
    }

    func assertRole(_ expectedRole: ConnectionRole) throws {
        if role != expectedRole {
            throw AriesFrameworkError.frameworkError("Connection record has invalid role \(role). Expected role \(expectedRole).")
        }
    }
}
