
import Foundation
import os

public struct OutOfBandRecord: BaseRecord {
    public var id: String
    var createdAt: Date
    var updatedAt: Date?
    public var tags: Tags?

    var outOfBandInvitation: OutOfBandInvitation
    var role: OutOfBandRole
    var state: OutOfBandState
    var reusable: Bool

    var autoAcceptConnection: Bool?
    var mediatorId: String?
    var reuseConnectionId: String?

    let logger = Logger(subsystem: "AriesFramework", category: "OutOfBandRecord")
    public static let type = "OutOfBandRecord"
}

extension OutOfBandRecord: Codable {
    enum CodingKeys: String, CodingKey {
        case id, createdAt, updatedAt, tags, outOfBandInvitation, role, state, reusable, autoAcceptConnection, mediatorId, reuseConnectionId
    }

    public func getTags() -> Tags {
        var tags = self.tags ?? [:]

        tags["state"] = self.state.rawValue
        tags["role"] = self.role.rawValue
        tags["invitationId"] = self.outOfBandInvitation.id
        tags["invitationKey"] = try? self.outOfBandInvitation.invitationKey()
        if let fingerprints = try? self.outOfBandInvitation.fingerprints() {
            if fingerprints.count > 0 {
                tags["recipientKeyFingerprint"] = fingerprints[0]
            } else {
                logger.error("OutOfBandInvitation has no recipientKey.")
            }
        } else {
            logger.error("Cannot get recipientKeyFingerprint.")
        }

        return tags
    }

    public func assertState(_ expectedStates: OutOfBandState...) throws {
        if !expectedStates.contains(state) {
            throw AriesFrameworkError.frameworkError("OutOfBand record is in invalid state \(state). Valid states are: \(expectedStates.map { $0.rawValue }.joined(separator: ", ")).")
        }
    }

    public func assertRole(_ expectedRole: OutOfBandRole) throws {
        if role != expectedRole {
            throw AriesFrameworkError.frameworkError("OutOfBand record has invalid role \(role). Expected role \(expectedRole).")
        }
    }
}
