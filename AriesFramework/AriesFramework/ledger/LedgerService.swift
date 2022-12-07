
import Foundation
import Indy
import os

public struct SchemaTemplate {
    public let name: String
    public let version: String
    public let attributes: [String]
}

public struct CredentialDefinitionTemplate {
    public let schema: String
    public let tag: String
    public let signatureType: String = "CL"
    public let supportRevocation: Bool
}

struct IndyResponse: Codable {
    let op: String
    let reason: String?
}

public class LedgerService {
    let agent: Agent
    let logger = Logger(subsystem: "AriesFramework", category: "LedgerService")
    private var indyPool: IndyHandle?

    let poolExistKey: String

    init(agent: Agent) {
        self.agent = agent
        poolExistKey = agent.agentConfig.label + " aries_framework_pool_exist"
    }

    func initialize() async throws {
        logger.info("Initializing Pool")
        if indyPool != nil {
          logger.warning("Pool already initialized.")
          try await close()
        }

        try await IndyPool.setProtocolVersion(2)
        let poolConfig = ["genesis_txn": agent.agentConfig.genesisPath].toString()
        let userDefaults = UserDefaults.standard
        if !userDefaults.bool(forKey: poolExistKey) {
            do {
                try await IndyPool.createPoolLedgerConfig(withPoolName: agent.agentConfig.poolName, poolConfig: poolConfig)
                userDefaults.set(true, forKey: poolExistKey)
            } catch {
                if let err = error as NSError? {
                    logger.error("Cannot create pool: \(err.userInfo["message"] as? String ?? "Unknown error")")
                }
                throw AriesFrameworkError.frameworkError("Pool creation failed")
            }
        }

        do {
            indyPool = try await IndyPool.openLedger(withName: agent.agentConfig.poolName, poolConfig: poolConfig)
        } catch {
            if let err = error as NSError? {
                logger.error("Cannot open pool: \(err.userInfo["message"] as? String ?? "Unknown error")")
            }
            throw AriesFrameworkError.frameworkError("Pool opening failed")
        }
    }

    public func registerSchema(did: String, schemaTemplate: SchemaTemplate) async throws -> String {
        let (schemaId, schema) = try await IndyAnoncreds.issuerCreateSchema(
            withName: schemaTemplate.name,
            version: schemaTemplate.version,
            attrs: schemaTemplate.attributes.toString(),
            issuerDID: did)

        guard let request = try await IndyLedger.buildSchemaRequest(
            withSubmitterDid: did,
            data: schema) else {
                throw AriesFrameworkError.frameworkError("Cannot build schema request")
        }
        try await submitWriteRequest(request, did: did)

        return schemaId!
    }

    public func getSchema(schemaId: String) async throws -> String {
        let request = try await IndyLedger.buildGetSchemaRequest(
            withSubmitterDid: nil,
            id: schemaId)
        let response = try await submitReadRequest(request!)
        let (_, schema) = try await IndyLedger.parseGetSchemaResponse(response)
        return schema!
    }

    public func registerCredentialDefinition(did: String, credentialDefinitionTemplate: CredentialDefinitionTemplate) async throws -> String {
        let (credDefId, credDef) = try await IndyAnoncreds.issuerCreateAndStoreCredentialDef(
            forSchema: credentialDefinitionTemplate.schema,
            issuerDID: did,
            tag: credentialDefinitionTemplate.tag,
            type: credentialDefinitionTemplate.signatureType,
            configJSON: ["support_revocation": credentialDefinitionTemplate.supportRevocation].toString(),
            walletHandle: agent.wallet.handle!)

        guard let request = try await IndyLedger.buildCredDefRequest(
            withSubmitterDid: did,
            data: credDef) else {
                throw AriesFrameworkError.frameworkError("Cannot build credential definition request")
            }
        try await submitWriteRequest(request, did: did)

        return credDefId!
    }

    public func getCredentialDefinition(id: String) async throws -> String {
        logger.debug("Get CredentialDefinition with id: \(id)")
        let request = try await IndyLedger.buildGetCredDefRequest(
            withSubmitterDid: nil,
            id: id)
        let response = try await submitReadRequest(request!)
        let (_, credDef) = try await IndyLedger.parseGetCredDefResponse(response)
        return credDef!
    }

    public func getRevocationRegistryDefinition(id: String) async throws -> String {
        logger.debug("Get RevocationRegistryDefinition with id: \(id)")
        let request = try await IndyLedger.buildGetRevocRegDefRequest(
            withSubmitterDid: nil,
            id: id)
        let response = try await submitReadRequest(request!)
        let (_, revocationRegistryDefinition) = try await IndyLedger.parseGetRevocRegDefResponse(response)
        return revocationRegistryDefinition!
    }

    public func getRevocationRegistryDelta(id: String, to: Int = Int(Date().timeIntervalSince1970), from: Int = 0) async throws -> (String, Int) {
        logger.debug("Get RevocationRegistryDelta with id: \(id)")
        let request = try await IndyLedger.buildGetRevocRegDeltaRequest(
            withSubmitterDid: nil,
            revocRegDefId: id,
            from: from as NSNumber,
            to: to as NSNumber)
        let response = try await submitReadRequest(request!)
        let (_, revocationRegistryDelta, deltaTimestamp) = try await IndyLedger.parseGetRevocRegDeltaResponse(response)
        return (revocationRegistryDelta!, Int(truncating: deltaTimestamp!))
    }

    public func getRevocationRegistry(id: String, timestamp: Int) async throws -> (String, Int) {
        logger.debug("Get RevocationRegistry with id: \(id), timestamp: \(timestamp)")
        let request = try await IndyLedger.buildGetRevocRegRequest(
            withSubmitterDid: nil,
            revocRegDefId: id,
            timestamp: timestamp as NSNumber)
        let response = try await submitReadRequest(request!)
        let (_, revocationRegistry, ledgerTimestamp) = try await IndyLedger.parseGetRevocRegResponse(response)
        return (revocationRegistry!, Int(truncating: ledgerTimestamp!))
    }

    func validateResponse(_ response: String) throws {
        let indyResponse = try JSONDecoder().decode(IndyResponse.self, from: response.data(using: .utf8)!)
        if indyResponse.op != "REPLY" {
            throw AriesFrameworkError.frameworkError("Submit request failed: \(indyResponse.reason ?? "Unknown error")")
        }
    }

    public func submitWriteRequest(_ request: String, did: String) async throws {
        if indyPool == nil {
            throw AriesFrameworkError.frameworkError("Pool is not initialized")
        }

        let response = try await IndyLedger.signAndSubmitRequest(request,
            submitterDID: did,
            poolHandle: indyPool!,
            walletHandle: agent.wallet.handle!)
        try validateResponse(response!)
    }

    public func submitReadRequest(_ request: String) async throws -> String {
        if indyPool == nil {
            throw AriesFrameworkError.frameworkError("Pool is not initialized")
        }

        let response = try await IndyLedger.submitRequest(request,
            poolHandle: indyPool!)
        try validateResponse(response!)
        return response!
    }

    func close() async throws {
        if indyPool != nil {
            try await IndyPool.closeLedger(withHandle: indyPool!)
            indyPool = nil
        }
    }

    func delete() async throws {
        if indyPool != nil {
            try? await close()
        }

        let userDefaults = UserDefaults.standard
        if userDefaults.bool(forKey: poolExistKey) {
            try await IndyPool.deleteLedgerConfig(withName: agent.agentConfig.poolName)
            userDefaults.removeObject(forKey: poolExistKey)
        }
    }
}
