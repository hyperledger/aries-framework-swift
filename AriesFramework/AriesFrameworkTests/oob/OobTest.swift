
import XCTest
@testable import AriesFramework

class OobTest: XCTestCase {

    var faberAgent: Agent!
    var aliceAgent: Agent!
    let makeConnectionConfig = CreateOutOfBandInvitationConfig(
        label: "Faber College",
        goalCode: "p2p-messaging",
        goal: "To make a connection")
    let receiveInvitationConfig = ReceiveOutOfBandInvitationConfig(
        autoAcceptConnection: true)
    let credentialPreview = CredentialPreview.fromDictionary(["name": "Alice", "age": "20"])

    override func setUp() async throws {
        try await super.setUp()

        let faberConfig = try TestHelper.getBaseConfig(name: "faber")
        faberAgent = Agent(agentConfig: faberConfig, agentDelegate: nil)
        try await faberAgent.initialize()

        let aliceConfig = try TestHelper.getBaseConfig(name: "alice")
        aliceAgent = Agent(agentConfig: aliceConfig, agentDelegate: nil)
        try await aliceAgent.initialize()

        faberAgent.setOutboundTransport(SubjectOutboundTransport(subject: aliceAgent))
        aliceAgent.setOutboundTransport(SubjectOutboundTransport(subject: faberAgent))
    }

    override func tearDown() async throws {
        try await faberAgent.reset()
        try await aliceAgent.reset()
        try await super.tearDown()
    }

    func prepareForCredentialTest() async throws -> CreateOfferOptions {
        try await faberAgent.reset()
        let faberConfig = try TestHelper.getBaseConfig(name: "faber", useLedgerSerivce: true)
        faberAgent = Agent(agentConfig: faberConfig, agentDelegate: nil)
        try await faberAgent.initialize()

        // faberAgent has changed, so reset SubjectOutboundTransports.
        faberAgent.setOutboundTransport(SubjectOutboundTransport(subject: aliceAgent))
        aliceAgent.setOutboundTransport(SubjectOutboundTransport(subject: faberAgent))

        let credDefId = try await TestHelper.prepareForIssuance(faberAgent, ["name", "age"])
        return CreateOfferOptions(
            credentialDefinitionId: credDefId,
            attributes: credentialPreview.attributes,
            autoAcceptCredential: .never)
    }

    func testCreateOutOfBandInvitation() async throws {
        let outOfBandRecord = try await faberAgent.oob.createInvitation(config: makeConnectionConfig)

        XCTAssertEqual(outOfBandRecord.autoAcceptConnection, true)
        XCTAssertEqual(outOfBandRecord.role, .Sender)
        XCTAssertEqual(outOfBandRecord.state, .AwaitResponse)
        XCTAssertEqual(outOfBandRecord.reusable, false)
        XCTAssertEqual(outOfBandRecord.outOfBandInvitation.goal, makeConnectionConfig.goal)
        XCTAssertEqual(outOfBandRecord.outOfBandInvitation.goalCode, makeConnectionConfig.goalCode)
        XCTAssertEqual(outOfBandRecord.outOfBandInvitation.label, makeConnectionConfig.label)
    }

    func testCreateWithHandshakeAndRequests() async throws {
        let message = TrustPingMessage(comment: "Hello")
        let config = CreateOutOfBandInvitationConfig(
            label: "test-connection",
            messages: [message])
        let outOfBandRecord = try await faberAgent.oob.createInvitation(config: config)
        let invitation = outOfBandRecord.outOfBandInvitation

        XCTAssertTrue(invitation.handshakeProtocols!.contains(.Connections))
        XCTAssertEqual(try invitation.getRequests().count, 1)
    }

    func testCreateWithOfferCredentialMessage() async throws {
        let offerOptions = try await prepareForCredentialTest()
        let (message, _) = try await faberAgent.credentialService.createOffer(options: offerOptions)
        let outOfBandRecord = try await faberAgent.oob.createInvitation(
            config: CreateOutOfBandInvitationConfig(messages: [message]))
        let invitation = outOfBandRecord.outOfBandInvitation

        XCTAssertNotNil(invitation.handshakeProtocols)
        XCTAssertEqual(try invitation.getRequests().count, 1)

        if case .oobDidDocument(let service) = invitation.services[0] {
            XCTAssertEqual(service.serviceEndpoint, DID_COMM_TRANSPORT_QUEUE)
            XCTAssertTrue(service.recipientKeys[0].starts(with: "did:key"))
        } else {
            XCTFail("Service is not OutOfBandDidDocumentService")
        }
    }

    func testReceiveInvitation() async throws {
        let outOfBandRecord = try await faberAgent.oob.createInvitation(config: makeConnectionConfig)
        let invitation = outOfBandRecord.outOfBandInvitation

        let (receivedOutOfBandRecord, _) = try await aliceAgent.oob.receiveInvitation(invitation)

        XCTAssertEqual(receivedOutOfBandRecord.role, .Receiver)
        XCTAssertEqual(receivedOutOfBandRecord.state, .Done)
        XCTAssertEqual(receivedOutOfBandRecord.outOfBandInvitation.goal, makeConnectionConfig.goal)
        XCTAssertEqual(receivedOutOfBandRecord.outOfBandInvitation.goalCode, makeConnectionConfig.goalCode)
        XCTAssertEqual(receivedOutOfBandRecord.outOfBandInvitation.label, makeConnectionConfig.label)
    }

    func testConnectionWithURL() async throws {
        let outOfBandRecord = try await faberAgent.oob.createInvitation(config: makeConnectionConfig)
        let invitation = outOfBandRecord.outOfBandInvitation
        let url = try invitation.toUrl(domain: "http://example.com")

        let (_, connection) = try await aliceAgent.oob.receiveInvitationFromUrl(url)
        guard let aliceFaberConnection = connection else {
            XCTFail("Connection is nil after receiving invitation from url")
            return
        }
        XCTAssertEqual(aliceFaberConnection.state, .Complete)

        guard let faberAliceConnection = await faberAgent.connectionService.findByInvitationKey(try invitation.invitationKey()!) else {
            XCTFail("Cannot find connection by invitation key")
            return
        }
        XCTAssertEqual(faberAliceConnection.state, .Complete)

        XCTAssertEqual(faberAliceConnection.alias, makeConnectionConfig.alias)
        XCTAssertEqual(TestHelper.isConnectedWith(received: faberAliceConnection, connection: aliceFaberConnection), true)
        XCTAssertEqual(TestHelper.isConnectedWith(received: aliceFaberConnection, connection: faberAliceConnection), true)
    }

    func testCredentialOffer() async throws {
        let offerOptions = try await prepareForCredentialTest()
        let (message, _) = try await faberAgent.credentialService.createOffer(options: offerOptions)
        let outOfBandRecord = try await faberAgent.oob.createInvitation(
            config: CreateOutOfBandInvitationConfig(messages: [message]))
        let invitation = outOfBandRecord.outOfBandInvitation

        let (_, connection) = try await aliceAgent.oob.receiveInvitation(invitation, config: receiveInvitationConfig)
        let credentialRecord = try await aliceAgent.credentialRepository.findByThreadAndConnectionId(
            threadId: message.threadId, connectionId: connection?.id)
        XCTAssertEqual(credentialRecord?.state, .OfferReceived)
    }

    func testWithHandskakeReuse() async throws {
        let routing = try await faberAgent.mediationRecipient.getRouting()
        let outOfBandRecord = try await faberAgent.oob.createInvitation(
            config: CreateOutOfBandInvitationConfig(routing: routing))
        let (_, firstAliceFaberConnection) = try await aliceAgent.oob.receiveInvitation(outOfBandRecord.outOfBandInvitation)

        let outOfBandRecord2 = try await faberAgent.oob.createInvitation(
            config: CreateOutOfBandInvitationConfig(routing: routing))
        let (_, secondAliceFaberConnection) = try await aliceAgent.oob.receiveInvitation(
            outOfBandRecord2.outOfBandInvitation, config: ReceiveOutOfBandInvitationConfig(reuseConnection: true))

        XCTAssertEqual(firstAliceFaberConnection!.id, secondAliceFaberConnection!.id)

        let faberConnections = await faberAgent.connectionRepository.getAll()
        XCTAssertEqual(faberConnections.count, 1)
    }

    func testWithoutHandshakeReuse() async throws {
        let routing = try await faberAgent.mediationRecipient.getRouting()
        let outOfBandRecord = try await faberAgent.oob.createInvitation(
            config: CreateOutOfBandInvitationConfig(routing: routing))
        let (_, firstAliceFaberConnection) = try await aliceAgent.oob.receiveInvitation(outOfBandRecord.outOfBandInvitation)

        let outOfBandRecord2 = try await faberAgent.oob.createInvitation(
            config: CreateOutOfBandInvitationConfig(routing: routing))
        let (_, secondAliceFaberConnection) = try await aliceAgent.oob.receiveInvitation(
            outOfBandRecord2.outOfBandInvitation, config: ReceiveOutOfBandInvitationConfig(reuseConnection: false))

        XCTAssertNotEqual(firstAliceFaberConnection!.id, secondAliceFaberConnection!.id)

        let faberConnections = await faberAgent.connectionRepository.getAll()
        XCTAssertEqual(faberConnections.count, 2)
    }

    func testReceivingSameInvition() async throws {
        let outOfBandRecord = try await faberAgent.oob.createInvitation(config: makeConnectionConfig)
        let invitation = outOfBandRecord.outOfBandInvitation

        let (_, firstAliceFaberConnection) = try await aliceAgent.oob.receiveInvitation(invitation)
        XCTAssertNotNil(firstAliceFaberConnection)

        do {
            let (_, _) = try await aliceAgent.oob.receiveInvitation(invitation)
            XCTFail("Should not be able to receive same invitation twice")
        } catch {
            // expected
        }
    }
}
