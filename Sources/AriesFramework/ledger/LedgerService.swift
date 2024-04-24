
import Foundation

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

public protocol LedgerService {
    func initialize() async throws
    func registerSchema(did: DidInfo, schemaTemplate: SchemaTemplate) async throws -> String
    func getSchema(schemaId: String) async throws -> (String, Int)
    func registerCredentialDefinition(did: DidInfo, credentialDefinitionTemplate: CredentialDefinitionTemplate) async throws -> String
    func getCredentialDefinition(id: String) async throws -> String
    func registerRevocationRegistryDefinition(did: DidInfo, revRegDefTemplate: RevocationRegistryDefinitionTemplate) async throws -> String
    func getRevocationRegistryDefinition(id: String) async throws -> String
    func getRevocationRegistryDelta(id: String, to: Int, from: Int) async throws -> (String, Int)
    func getRevocationRegistry(id: String, timestamp: Int) async throws -> (String, Int)
    func revokeCredential(did: DidInfo, credDefId: String, revocationIndex: Int) async throws
    func close() async throws
}
