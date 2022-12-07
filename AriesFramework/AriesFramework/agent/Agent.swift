
import Foundation
import Indy

public class Agent {
    public var agentConfig: AgentConfig
    public var agentDelegate: AgentDelegate?

    var mediationRecipient: MediationRecipient!
    public var connectionRepository: ConnectionRepository!
    public var connectionService: ConnectionService!
    var messageSender: MessageSender!
    var messageReceiver: MessageReceiver!
    public var dispatcher: Dispatcher!
    public var connections: ConnectionCommand!
    var outOfBandRepository: OutOfBandRepository!
    var outOfBandService: OutOfBandService!
    public var oob: OutOfBandCommand!
    public var credentialRepository: CredentialRepository!
    public var didCommMessageRepository: DidCommMessageRepository!
    public var ledgerService: LedgerService!
    public var revocationService: RevocationService!
    public var credentialService: CredentialService!
    public var credentials: CredentialsCommand!
    public var proofRepository: ProofRepository!
    public var proofService: ProofService!
    public var proofs: ProofCommand!

    public var wallet: Wallet!
    private var _isInitialized = false

    public init(agentConfig: AgentConfig, agentDelegate: AgentDelegate?) {
        self.agentConfig = agentConfig
        self.agentDelegate = agentDelegate

        self.wallet = Wallet(agent: self)
        self.connectionRepository = ConnectionRepository(agent: self)
        self.connectionService = ConnectionService(agent: self)
        self.messageSender = MessageSender(agent: self)
        self.messageReceiver = MessageReceiver(agent: self)
        self.dispatcher = Dispatcher(agent: self)
        self.connections = ConnectionCommand(agent: self, dispatcher: self.dispatcher)
        self.mediationRecipient = MediationRecipient(agent: self, dispatcher: self.dispatcher)
        self.outOfBandRepository = OutOfBandRepository(agent: self)
        self.outOfBandService = OutOfBandService(agent: self)
        self.oob = OutOfBandCommand(agent: self, dispatcher: self.dispatcher)
        self.credentialRepository = CredentialRepository(agent: self)
        self.didCommMessageRepository = DidCommMessageRepository(agent: self)
        self.ledgerService = LedgerService(agent: self)
        self.revocationService = RevocationService(agent: self)
        self.credentialService = CredentialService(agent: self)
        self.credentials = CredentialsCommand(agent: self, dispatcher: self.dispatcher)
        self.proofRepository = ProofRepository(agent: self)
        self.proofService = ProofService(agent: self)
        self.proofs = ProofCommand(agent: self, dispatcher: self.dispatcher)
    }

    /**
     Initialize the agent. This will create a wallet if necessary and open it.
     It will also connect to the mediator if configured and connect to the ledger.
    */
    public func initialize() async throws {
        if let rustLogEnvVar = ProcessInfo.processInfo.environment["RUST_LOG"] {
            IndyLogger.setDefault(rustLogEnvVar)
        }

        try await wallet.initialize()

        if let publicDidSeed = agentConfig.publicDidSeed {
            try await wallet.initPublicDid(seed: publicDidSeed)
        }

        if agentConfig.useLedgerSerivce {
            try await ledgerService.initialize()
        }

        if let mediatorConnectionsInvite = agentConfig.mediatorConnectionsInvite {
            try await mediationRecipient.initialize(mediatorConnectionsInvite: mediatorConnectionsInvite)
        } else {
            setInitialized()
        }
    }

    /**
     Whether the agent is initialized. Agent should make new connections after it is initialized.
    */
    public func isInitialized() -> Bool {
        return self._isInitialized
    }

    /**
     Remove the wallet and ledger data. This makes the agent as if it was never initialized.
    */
    public func reset() async throws {
        if isInitialized() {
            try await shutdown()
        }
        try await wallet.delete()
        try await ledgerService.delete()
    }

    /**
     Shutdown the agent. This will close the wallet, disconnect from the ledger, disconnect from the mediator and close open websockets.
    */
    public func shutdown() async throws {
        mediationRecipient.close()
        try await ledgerService.close()
        await messageSender.close()
        if wallet.handle != nil {
            try await wallet.close()
        }
        self._isInitialized = false
    }

    func setInitialized() {
        self._isInitialized = true
    }

    func receiveMessage(_ encryptedMessage: EncryptedMessage) async throws {
        try await messageReceiver.receiveMessage(encryptedMessage)
    }

    /**
     Set the outbound transport for the agent. This will override the default http/websocket transport.
     It is useful for testing.
    */
    public func setOutboundTransport(_ outboundTransport: OutboundTransport) {
        self.messageSender.setOutboundTransport(outboundTransport)
    }
}
