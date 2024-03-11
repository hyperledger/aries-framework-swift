
import Foundation
import os
import IndyVdr
import Anoncreds

public struct SchemaTemplate {
    public let name: String
    public let version: String
    public let attributes: [String]
}

public struct CredentialDefinitionTemplate {
    public let schema: String
    public let tag: String
    public let supportRevocation: Bool
    public let seqNo: Int
}

public struct RevocationRegistryDefinitionTemplate {
    public let credDefId: String
    public let tag: String
    public let maxCredNum: Int
    public let tailsDirPath: String? = nil
}

public class LedgerService {
    let agent: Agent
    let logger = Logger(subsystem: "AriesFramework", category: "LedgerService")
    private var pool: Pool?
    private let ledger = Ledger()
    private let issuer = Issuer()

    init(agent: Agent) {
        self.agent = agent
    }

    func initialize() async throws {
        logger.info("Initializing Pool")
        if pool != nil {
          logger.warning("Pool already initialized.")
          try await close()
        }

        try setProtocolVersion(version: 2)
        do {
            pool = try openPool(transactionsPath: agent.agentConfig.genesisPath, transactions: nil, nodeWeights: nil)
        } catch {
            throw AriesFrameworkError.frameworkError("Pool opening failed: \(error)")
        }

        Task {
            try await self.pool?.refresh()
            let status = try await self.pool?.getStatus()
            logger.debug("Pool status: \(status.debugDescription)")
        }
    }

    public func registerSchema(did: DidInfo, schemaTemplate: SchemaTemplate) async throws -> String {
        logger.debug("registering schema")
        let schema = try issuer.createSchema(
            schemaName: schemaTemplate.name,
            schemaVersion: schemaTemplate.version,
            issuerId: did.did,
            attrNames: schemaTemplate.attributes)
        let indySchema = [
            "name": schemaTemplate.name,
            "version": schemaTemplate.version,
            "attrNames": schemaTemplate.attributes,
            "ver": "1.0",
            "id": schema.schemaId()
        ] as [String: Any]
        let indySchemaJson = try JSONSerialization.data(withJSONObject: indySchema)

        let request = try ledger.buildSchemaRequest(
            submitterDid: did.did,
            schema: String(data: indySchemaJson, encoding: .utf8)!)
        try await submitWriteRequest(request, did: did)

        return schema.schemaId()
    }

    public func getSchema(schemaId: String) async throws -> (String, Int) {
        logger.debug("Get Schema with id: \(schemaId)")
        let request = try ledger.buildGetSchemaRequest(submitterDid: nil, schemaId: schemaId)
        let res = try await submitReadRequest(request)
        let response = try JSONDecoder().decode(SchemaResponse.self, from: res.data(using: .utf8)!)
        guard let seqNo = response.result.seqNo, let attrNames = response.result.data.attr_names else {
            logger.debug("response: \(res)")
            throw AriesFrameworkError.frameworkError("Invalid schema response")
        }

        let issuer = schemaId.split(separator: ":")[0]
        let schema = [
            "name": response.result.data.name,
            "version": response.result.data.version,
            "issuerId": issuer,
            "attrNames": attrNames
        ] as [String: Any]
        let schemaJson = try JSONSerialization.data(withJSONObject: schema)

        return (String(data: schemaJson, encoding: .utf8)!, seqNo)
    }

    public func registerCredentialDefinition(did: DidInfo, credentialDefinitionTemplate: CredentialDefinitionTemplate) async throws -> String {
        logger.debug("registering credential definition")
        let schema = try Schema(json: credentialDefinitionTemplate.schema)
        let credDefTuple = try issuer.createCredentialDefinition(
            schemaId: schema.schemaId(),
            schema: schema,
            tag: credentialDefinitionTemplate.tag,
            issuerId: did.did,
            supportRevocation: credentialDefinitionTemplate.supportRevocation)

        // Indy requires seqNo as schemaId for cred def registration.
        let credDefId = "\(did.did):3:CL:\(credentialDefinitionTemplate.seqNo):\(credentialDefinitionTemplate.tag)"
        // swiftlint:disable:next force_cast
        var credDef = try JSONSerialization.jsonObject(with: credDefTuple.credDef.toJson().data(using: .utf8)!) as! [String: Any]
        credDef["id"] = credDefId
        credDef["ver"] = "1.0"
        credDef["schemaId"] = String(credentialDefinitionTemplate.seqNo)
        let credDefJson = try JSONSerialization.data(withJSONObject: credDef)
        let request = try ledger.buildCredDefRequest(
            submitterDid: did.did,
            credDef: String(data: credDefJson, encoding: .utf8)!)
        try await submitWriteRequest(request, did: did)

        let record = CredentialDefinitionRecord(
            schemaId: schema.schemaId(),
            credDefId: credDefId,
            credDef: credDefTuple.credDef.toJson(),
            credDefPriv: credDefTuple.credDefPriv.toJson(),
            keyCorrectnessProof: credDefTuple.keyCorrectnessProof.toJson())
        try await agent.credentialDefinitionRepository.save(record)

        return credDefId
    }

    public func getCredentialDefinition(id: String) async throws -> String {
        logger.debug("Get CredentialDefinition with id: \(id)")
        let request = try ledger.buildGetCredDefRequest(submitterDid: nil, credDefId: id)
        let response = try await submitReadRequest(request)
        let json = try JSONSerialization.jsonObject(with: response.data(using: .utf8)!) as? [String: Any]
        guard let result = json?["result"] as? [String: Any],
              let data = result["data"] as? [String: Any],
              let tag = result["tag"] as? String,
              let type = result["signature_type"] as? String,
              let ref = result["ref"] as? Int else {
            throw AriesFrameworkError.frameworkError("Invalid cred def response")
        }

        let issuer = id.split(separator: ":")[0]
        let credDef = [
            "issuerId": issuer,
            "schemaId": String(ref),    // This is what indy-sdk does.
            "type": type,
            "tag": tag,
            "value": data
        ] as [String: Any]
        let credDefJson = try JSONSerialization.data(withJSONObject: credDef)

        return String(data: credDefJson, encoding: .utf8)!
    }

    public func registerRevocationRegistryDefinition(did: DidInfo, revRegDefTemplate: RevocationRegistryDefinitionTemplate) async throws -> String {
        logger.debug("registering revocation registry definition")
        let credentialDefinitionRecord = try await agent.credentialDefinitionRepository.getByCredDefId(revRegDefTemplate.credDefId)
        let credDef = try CredentialDefinition(json: credentialDefinitionRecord.credDef)
        let regDefTuple = try issuer.createRevocationRegistryDef(
            credDef: credDef,
            credDefId: revRegDefTemplate.credDefId,
            tag: revRegDefTemplate.tag,
            maxCredNum: UInt32(revRegDefTemplate.maxCredNum),
            tailsDirPath: revRegDefTemplate.tailsDirPath)
        let revRegId  = regDefTuple.revRegDef.revRegId()
        let revocationStatusList = try issuer.createRevocationStatusList(
            credDef: credDef,
            revRegDefId: revRegId,
            revRegDef: regDefTuple.revRegDef,
            revRegPriv: regDefTuple.revRegDefPriv,
            timestamp: UInt64(Date().timeIntervalSince1970),
            issuanceByDefault: true)

        // swiftlint:disable:next force_cast
        var regDef = try JSONSerialization.jsonObject(with: regDefTuple.revRegDef.toJson().data(using: .utf8)!) as! [String: Any]
        regDef["id"] = revRegId
        regDef["ver"] = "1.0"
        guard var value = regDef["value"] as? [String: Any] else {
            throw AriesFrameworkError.frameworkError("Invalid RevocationRegistryDefinition. value is missing.")
        }
        value["issuanceType"] = "ISSUANCE_BY_DEFAULT"
        regDef["value"] = value
        let regDefJson = try JSONSerialization.data(withJSONObject: regDef)
        var request = try ledger.buildRevocRegDefRequest(
            submitterDid: did.did,
            revRegDef: String(data: regDefJson, encoding: .utf8)!)
        try await submitWriteRequest(request, did: did)

        let statusList = try JSONDecoder().decode(RevocationStatusList.self, from: revocationStatusList.toJson().data(using: .utf8)!)
        let regDelta = RevocationRegistryDelta(prevAccum: nil, accum: statusList.currentAccumulator, issued: nil, revoked: nil)
        request = try ledger.buildRevocRegEntryRequest(
            submitterDid: did.did,
            revRegDefId: revRegId,
            entry: regDelta.toVersionedJson())
        try await submitWriteRequest(request, did: did)

        let record = RevocationRegistryRecord(
            credDefId: revRegDefTemplate.credDefId,
            revocRegId: revRegId,
            revocRegDef: regDefTuple.revRegDef.toJson(),
            revocRegPrivate: regDefTuple.revRegDefPriv.toJson(),
            revocStatusList: revocationStatusList.toJson())
        try await agent.revocationRegistryRepository.save(record)

        return revRegId
    }

    public func getRevocationRegistryDefinition(id: String) async throws -> String {
        logger.debug("Get RevocationRegistryDefinition with id: \(id)")
        let request = try ledger.buildGetRevocRegDefRequest(submitterDid: nil, revRegId: id)
        let response = try await submitReadRequest(request)
        let json = try JSONSerialization.jsonObject(with: response.data(using: .utf8)!) as? [String: Any]
        guard let result = json?["result"] as? [String: Any],
              var data = result["data"] as? [String: Any] else {
            throw AriesFrameworkError.frameworkError("Invalid rev reg def response")
        }
        data["issuerId"] = id.split(separator: ":")[0]
        let revocationRegistryDefinition = try JSONSerialization.data(withJSONObject: data)

        return String(data: revocationRegistryDefinition, encoding: .utf8)!
    }

    public func getRevocationRegistryDelta(id: String, to: Int = Int(Date().timeIntervalSince1970), from: Int = 0) async throws -> (String, Int) {
        logger.debug("Get RevocationRegistryDelta with id: \(id)")
        let request = try ledger.buildGetRevocRegDeltaRequest(submitterDid: nil, revRegId: id, from: Int64(from), to: Int64(to))
        let res = try await submitReadRequest(request)
        let response = try JSONDecoder().decode(RevRegDeltaResponse.self, from: res.data(using: .utf8)!)
        let revocationRegistryDelta = RevocationRegistryDelta(
            prevAccum: response.result.data.value.accum_from?.value.accum,
            accum: response.result.data.value.accum_to.value.accum,
            issued: response.result.data.value.issued,
            revoked: response.result.data.value.revoked)
        let deltaTimestamp = response.result.data.value.accum_to.txnTime
        return (revocationRegistryDelta.toJsonString(), deltaTimestamp)
    }

    public func getRevocationRegistry(id: String, timestamp: Int) async throws -> (String, Int) {
        logger.debug("Get RevocationRegistry with id: \(id), timestamp: \(timestamp)")
        let request = try ledger.buildGetRevocRegRequest(submitterDid: nil, revRegId: id, timestamp: Int64(timestamp))
        let response = try await submitReadRequest(request)
        let json = try JSONSerialization.jsonObject(with: response.data(using: .utf8)!) as? [String: Any]
        guard let result = json?["result"] as? [String: Any],
              let data = result["data"] as? [String: Any],
              let value = data["value"] as? [String: String],
              let txnTime = result["txnTime"] as? Int else {
            throw AriesFrameworkError.frameworkError("Invalid rev reg response: \(response)")
        }
        let revocationRegistry = try JSONSerialization.data(withJSONObject: value)
        return (String(data: revocationRegistry, encoding: .utf8)!, txnTime)
    }

    public func revokeCredential(did: DidInfo, credDefId: String, revocationIndex: Int) async throws {
        logger.debug("Revoking credential with index: \(revocationIndex)")
        let credentialDefinitionRecord = try await agent.credentialDefinitionRepository.getByCredDefId(credDefId)
        guard var revocationRecord = try await agent.revocationRegistryRepository.findByCredDefId(credDefId) else {
            throw AriesFrameworkError.frameworkError("No revocation registry found for credential definition id: \(credDefId)")
        }

        let currentStatusList = try Anoncreds.RevocationStatusList(json: revocationRecord.revocStatusList)
        let revokedStatusList = try issuer.updateRevocationStatusList(
            credDef: try CredentialDefinition(json: credentialDefinitionRecord.credDef),
            timestamp: UInt64(Date().timeIntervalSince1970),
            issued: nil,
            revoked: [UInt32(revocationIndex)],
            revRegDef: try RevocationRegistryDefinition(json: revocationRecord.revocRegDef),
            revRegPriv: try RevocationRegistryDefinitionPrivate(json: revocationRecord.revocRegPrivate),
            currentList: currentStatusList)

        let currentList = try JSONDecoder().decode(RevocationStatusList.self, from: currentStatusList.toJson().data(using: .utf8)!)
        let revokedList = try JSONDecoder().decode(RevocationStatusList.self, from: revokedStatusList.toJson().data(using: .utf8)!)
        let regDelta = RevocationRegistryDelta(prevAccum: currentList.currentAccumulator, accum: revokedList.currentAccumulator, issued: nil, revoked: [revocationIndex])
        let request = try ledger.buildRevocRegEntryRequest(
            submitterDid: did.did,
            revRegDefId: revocationRecord.revocRegId,
            entry: regDelta.toVersionedJson())
        try await submitWriteRequest(request, did: did)

        revocationRecord.revocStatusList = revokedStatusList.toJson()
        try await agent.revocationRegistryRepository.update(revocationRecord)
    }

    func validateResponse(_ response: String) throws {
        let indyResponse = try JSONDecoder().decode(IndyResponse.self, from: response.data(using: .utf8)!)
        if indyResponse.op != "REPLY" {
            throw AriesFrameworkError.frameworkError("Submit request failed: \(indyResponse.reason ?? "Unknown error")")
        }
    }

    public func submitWriteRequest(_ request: Request, did: DidInfo) async throws {
        if pool == nil {
            throw AriesFrameworkError.frameworkError("Pool is not initialized")
        }

        guard let signKey = try await agent.wallet.session!.fetchKey(name: did.verkey, forUpdate: false) else {
            throw AriesFrameworkError.frameworkError("Key not found: \(did.verkey)")
        }
        let signatureData = try request.signatureInput().data(using: .utf8)!
        let signature = try signKey.loadLocalKey().signMessage(message: signatureData, sigType: nil)
        try request.setSignature(signature: signature)

        let response = try await pool!.submitRequest(request: request)
        try validateResponse(response)
    }

    public func submitReadRequest(_ request: Request) async throws -> String {
        if pool == nil {
            throw AriesFrameworkError.frameworkError("Pool is not initialized")
        }

        let response = try await pool!.submitRequest(request: request)
        try validateResponse(response)
        return response
    }

    func close() async throws {
        if pool != nil {
            try await pool!.close()
            pool = nil
        }
    }
}
