
@testable import AriesFramework
import Indy
import os

let SECOND = 1000000000.0

class TestHelper {
    class XCTestExpectation {
        let description: String
        var isFulfilled = false

        init(description: String) {
            self.description = description
        }

        func fulfill() {
            isFulfilled = true
        }
    }

    static let logger = Logger(subsystem: "AriesFramework", category: "TestHelper")

    static func expectation(description: String) -> XCTestExpectation {
        return XCTestExpectation(description: description)
    }

    // An alternative wait function. Waiting functions of XCTest blocks the Runloop used by IndyCrypto.unpackMessage().
    static func wait(for expectation: XCTestExpectation, timeout: TimeInterval) async throws {
        let timeoutTimestamp = Date.timeIntervalSinceReferenceDate + timeout
        while !expectation.isFulfilled {
            if Date.timeIntervalSinceReferenceDate > timeoutTimestamp {
                throw AriesFrameworkError.frameworkError("Failed to fulfill expectation \"\(expectation.description)\" within \(timeout) seconds")
            }
            try await Task.sleep(nanoseconds: UInt64(0.1 * SECOND))
        }
    }

    static func getBaseConfig(name: String, useLedgerSerivce: Bool = false) throws -> AgentConfig {
        let key = "HfyxAyKK8Z2xVzWbXXy2erY32B9Bnr8WFgR5HfzjAnGx"
        guard let genesisPath = Bundle(for: TestHelper.self).path(forResource: "local-genesis", ofType: "txn") else {
            throw AriesFrameworkError.frameworkError("Cannot find local-genesis.txn")
        }
        let config = AgentConfig(walletId: "AFSTestWallet: \(name)",
            walletKey: key,
            genesisPath: genesisPath,
            poolName: "AFSTestPool: \(name)",
            mediatorConnectionsInvite: nil,
            label: "Agent: \(name)",
            autoAcceptCredential: .never,
            autoAcceptProof: .never,
            useLedgerSerivce: useLedgerSerivce,
            publicDidSeed: "000000000000000000000000Trustee1")
        return config
    }

    static func getBcovinConfig(name: String) throws -> AgentConfig {
        guard let genesisPath = Bundle(for: TestHelper.self).path(forResource: "bcovrin-genesis", ofType: "txn") else {
            throw AriesFrameworkError.frameworkError("Cannot find bcovrin-genesis.txn")
        }
        var config = try getBaseConfig(name: name, useLedgerSerivce: true)
        config.genesisPath = genesisPath
        config.autoAcceptCredential = .always

        return config
    }

    static func getMockConnection(state: ConnectionState? = nil) -> ConnectionRecord {
        return ConnectionRecord(
            state: state ?? ConnectionState.Invited,
            role: ConnectionRole.Invitee,
            didDoc: DidDoc(
                id: "test-did",
                publicKey: [],
                service: [
                    DidDocService.didComm(DidCommService(
                        id: "test-did;indy",
                        serviceEndpoint: "https://endpoint.com",
                        recipientKeys: ["key-1"]
                    ))
                ],
                authentication: []
            ),
            did: "test-did",
            verkey: "key-1",
            theirDidDoc: DidDoc(
                id: "their-did",
                publicKey: [],
                service: [
                    DidDocService.didComm(DidCommService(
                        id: "their-did;indy",
                        serviceEndpoint: "https://endpoint.com",
                        recipientKeys: ["key-1"]
                    ))
                ],
                authentication: []
            ),
            theirDid: "their-did",
            theirLabel: "their label",
            invitation: ConnectionInvitationMessage(
                id: "test",
                label: "test",
                recipientKeys: ["key-1"],
                serviceEndpoint: "https:endpoint.com/msg"
            ),
            multiUseInvitation: false
        )
    }

    static func getMockOutOfBand(role: OutOfBandRole, state: OutOfBandState, reusable: Bool, reuseConnectionId: String? = nil) throws -> OutOfBandRecord {
        let json: String = """
        {
            "@type": "https://didcomm.org/out-of-band/1.1/invitation",
            "@id": "69212a3a-d068-4f9d-a2dd-4741bca89af3",
            "label": "Faber College",
            "goal_code": "issue-vc",
            "goal": "To issue a Faber College Graduate credential",
            "handshake_protocols": ["https://didcomm.org/didexchange/1.0", "https://didcomm.org/connections/1.0"],
            "services": [
                {
                    "id": "#inline",
                    "type": "did-communication",
                    "recipientKeys": ["did:key:z6MkmjY8GnV5i9YTDtPETC2uUAW6ejw3nk5mXF5yci5ab7th"],
                    "routingKeys": ["did:key:z6MkmjY8GnV5i9YTDtPETC2uUAW6ejw3nk5mXF5yci5ab7th"],
                    "serviceEndpoint": "https://example.com/ssi",
                }
            ]
        }
        """

        let invitation = try OutOfBandInvitation.fromJson(json)
        let outOfBandRecord = OutOfBandRecord(
            id: "69212a3a-d068-4f9d-a2dd-4741bca89af3",
            createdAt: Date(),
            outOfBandInvitation: invitation,
            role: role,
            state: state,
            reusable: reusable,
            reuseConnectionId: reuseConnectionId)

        return outOfBandRecord
    }

    static func isConnectedWith(received: ConnectionRecord, connection: ConnectionRecord) -> Bool {
        do {
            try received.assertReady()
            try connection.assertReady()
        } catch {
            return false
        }

        return (received.theirDid == connection.did && received.theirKey() == connection.verkey)
    }

    static func setupCredentialTests() async throws -> (Agent, Agent, String, ConnectionRecord, ConnectionRecord) {
        let faberConfig = try TestHelper.getBaseConfig(name: "faber", useLedgerSerivce: true)
        let aliceConfig = try TestHelper.getBaseConfig(name: "alice", useLedgerSerivce: true)

        let faberAgent = Agent(agentConfig: faberConfig, agentDelegate: nil)
        let aliceAgent = Agent(agentConfig: aliceConfig, agentDelegate: nil)

        faberAgent.setOutboundTransport(SubjectOutboundTransport(subject: aliceAgent))
        aliceAgent.setOutboundTransport(SubjectOutboundTransport(subject: faberAgent))

        try await faberAgent.initialize()
        try await aliceAgent.initialize()

        let credDefId = try await prepareForIssuance(faberAgent, ["name", "age"])
        let (faberConnection, aliceConnection) = try await makeConnection(faberAgent, aliceAgent)

        return (faberAgent, aliceAgent, credDefId, faberConnection, aliceConnection)
    }

    static func prepareForIssuance(_ agent: Agent, _ attributes: [String]) async throws -> String {
        logger.debug("Preparing for issuance")
        guard let didInfo = agent.wallet.publicDid else {
            throw AriesFrameworkError.frameworkError("Agent has no public DID.")
        }
        let schemaId = try await agent.ledgerService.registerSchema(did: didInfo.did,
            schemaTemplate: SchemaTemplate(name: "schema-\(UUID().uuidString)", version: "1.0", attributes: attributes))
        let schema = try await agent.ledgerService.getSchema(schemaId: schemaId)
        logger.debug("Registering credential definition")
        let credDefId = try await agent.ledgerService.registerCredentialDefinition(did: didInfo.did,
            credentialDefinitionTemplate: CredentialDefinitionTemplate(schema: schema, tag: "default", supportRevocation: false))

        return credDefId
    }

    static func makeConnection(_ agentA: Agent, _ agentB: Agent) async throws -> (ConnectionRecord, ConnectionRecord) {
        logger.debug("Making connection")
        let message = try await agentA.connections.createConnection()
        // swiftlint:disable:next force_cast
        let invitation = message.payload as! ConnectionInvitationMessage
        var agentAConnection = message.connection
        var agentBConnection = try await agentB.connections.receiveInvitation(invitation)

        try await Task.sleep(nanoseconds: UInt64(0.1 * SECOND))

        agentAConnection = try await agentA.connectionRepository.getById(agentAConnection.id)
        agentBConnection = try await agentB.connectionRepository.getById(agentBConnection.id)

        return (agentAConnection, agentBConnection)
    }
}
