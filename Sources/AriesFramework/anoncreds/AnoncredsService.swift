import Foundation
import os
import Anoncreds

public struct AnoncredsService {
    let agent: Agent
    let logger = Logger(subsystem: "AriesFramework", category: "AnoncredsService")
    let secretCategory = "link-secret-category"

    init(agent: Agent) {
        self.agent = agent
    }

    public func createLinkSecret() async throws -> String {
        let linkSecretId = UUID().uuidString
        let linkSecret = try Anoncreds.createLinkSecret()
        try await agent.wallet.session!.update(operation: .insert, category: secretCategory, name: linkSecretId, value: linkSecret.data(using: .utf8)!, tags: nil, expiryMs: nil)

        return linkSecretId
    }

    public func getLinkSecret(id: String) async throws -> String {
        guard let linkSecret = try await agent.wallet.session!.fetch(category: secretCategory, name: id, forUpdate: false) else {
            throw AriesFrameworkError.recordNotFoundError("Link secret not found for id \(id)")
        }
        return String(data: linkSecret.value(), encoding: .utf8)!
    }

    func getCredentialsForProofRequest(_ proofRequest: ProofRequest, referent: String) async throws -> [IndyCredentialInfo] {
        guard let requestedAttribute = proofRequest.requestedAttributes[referent] ?? proofRequest.requestedPredicates[referent]?.asProofAttributeInfo() else {
            throw AriesFrameworkError.frameworkError("Referent not found in proof request")
        }

        var tags = Tags()
        if requestedAttribute.names == nil && requestedAttribute.name == nil {
            throw AriesFrameworkError.frameworkError("Proof request attribute must have either name or names")
        }
        if requestedAttribute.names != nil && requestedAttribute.name != nil {
            throw AriesFrameworkError.frameworkError("Proof request attribute cannot have both name and names")
        }
        let attributes = requestedAttribute.names ?? [requestedAttribute.name!]
        for attribute in attributes {
            tags["attr::\(attribute)::marker"] = "1"
        }

        if let restrictions = requestedAttribute.restrictions {
            let restrictionTag = queryFromRestrictions(restrictions)
            tags.merge(restrictionTag) { (_, new) in new }
        }

        let credentials = await agent.credentialRepository.findByQuery(tags.toString())
        return credentials.map { credentialRecord -> IndyCredentialInfo in
            return IndyCredentialInfo(
                referent: credentialRecord.credentialId,
                attributes: [:], // We don't use attrs.
                schemaId: credentialRecord.schemaId,
                credentialDefinitionId: credentialRecord.credentialDefinitionId,
                revocationRegistryId: credentialRecord.revocationRegistryId,
                credentialRevocationId: credentialRecord.credentialRevocationId
            )}

    }

    func queryFromRestrictions(_ restrictions: [AttributeFilter]) -> Tags {
        var tags = Tags()
        for restriction in restrictions {
            if let schemaId = restriction.schemaId {
                tags["schemaId"] = schemaId
            }
            if let schemaName = restriction.schemaName {
                tags["schemaName"] = schemaName
            }
            if let schemaVersion = restriction.schemaVersion {
                tags["schemaVersion"] = schemaVersion
            }
            if let schemaIssuerDid = restriction.schemaIssuerDid {
                tags["schemaIssuerId"] = schemaIssuerDid
            }
            if let issuerDid = restriction.issuerDid {
                tags["issuerId"] = issuerDid
            }
            if let credentialDefinitionId = restriction.credentialDefinitionId {
                tags["credentialDefinitionId"] = credentialDefinitionId
            }
        }
        return tags
    }
}
