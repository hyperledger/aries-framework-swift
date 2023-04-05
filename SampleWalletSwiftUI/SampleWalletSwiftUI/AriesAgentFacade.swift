import Foundation
import os
import Security
import AriesFramework
import Indy

enum AgentMenu: Identifiable {
    case qrcode, list, loading
    var id: Int {
        hashValue
    }
}

enum ActionType: Identifiable {
    case credOffer, proofRequest
    var id: Int {
        hashValue
    }
}

struct CredentialRecord : Codable, Hashable {
    var referent: String
    var attrs: [String: String]
    var schema_id: String
    var cred_def_id: String
    var rev_reg_id: String?
    var cred_rev_id: String?
}

extension Data {
    func string() -> String {
        return String(decoding: self, as: UTF8.self)
    }
}

extension AriesAgentFacade: AgentDelegate {
    
    func onCredentialStateChanged(credentialRecord: CredentialExchangeRecord) {
        if credentialRecord.state == .OfferReceived {
            credentialRecordId = credentialRecord.id
            processCredentialOffer()
        } else if credentialRecord.state == .Done {
            menu = nil
            showSimpleAlert(message: "Credential received")
        }
    }

    func onProofStateChanged(proofRecord: ProofExchangeRecord) {
        if proofRecord.state == .RequestReceived {
            proofRecordId = proofRecord.id
            processVerify()
        } else if proofRecord.state == .Done {
            menu = nil
            showSimpleAlert(message: "Proof done")
        }
    }
}

class AriesAgentFacade : ObservableObject {
    
    private let logger = Logger(subsystem: "SampleWalletSwiftUI", category: "AriesAgentFacade")
    
    var agent: Agent?
    @Published var isProvisioned = false
    @Published var isReady = false
    @Published var walletKeySeed = ""
    @Published var walletKey = ""
    @Published var availableNetworks: [URL] = []
    @Published var agentConfigIdForSelectedNetwork: String?
    @Published var walletIdForSelectedNetwork: String?
    @Published var selectedNetwork: URL? {
        willSet (url) {
            if url == nil {
                self.isProvisioned = false
            } else {
                let networkName = url!.deletingPathExtension().lastPathComponent
                self.agentConfigIdForSelectedNetwork = "agentConfig_\(networkName)"
                self.walletIdForSelectedNetwork = "wallet_\(networkName)"
                self.isProvisioned = UserDefaults.standard.value(forKey:"agentConfig_\(networkName)") != nil
            }
        }
    }
    
    @Published var agentInitialized = false
    @Published var confirmMessage = ""
    @Published var actionType: ActionType?
    @Published var alertMessage = ""
    @Published var showAlert = false
    @Published var menu: AgentMenu?
    @Published var connectionList: [ConnectionRecord] = []
    @Published var selectedConnection: ConnectionRecord?
    @Published var connectionInvitation: String = ""
    
    @Published var credentials: [CredentialRecord] = []
    
    init() {
        logger.debug("initialize aries agent facade.")
        self.availableNetworks = getGenesisTxnURLs()
        if self.availableNetworks.count > 0 {
            self.selectedNetwork = self.availableNetworks.first
        }
    }
    
    func getDefaultAgentConfig() -> AgentConfig {
        return AgentConfig(
            walletId: "AFSDefaultWallet",
            walletKey: nil,
            genesisPath: "",
            poolName: "AFSDefaultPool",
            mediatorConnectionsInvite: nil,
            mediatorPickupStrategy: .Implicit,
            label: "SwiftFrameworkAgent",
            autoAcceptConnections: true,
            mediatorPollingInterval: 10,
            mediatorEmptyReturnRetryInterval: 3,
            connectionImageUrl: nil,
            autoAcceptCredential: .always,
            autoAcceptProof: .always,
            useLedgerSerivce: true,
            useLegacyDidSovPrefix: true,
            publicDidSeed: nil,
            agentEndpoints: nil)
    }
    
    func walletKeyFromSeed() async throws -> String? {
        do {
            let seed = self.walletKeySeed.padding(toLength:32, withPad:" ", startingAt:0)
            let key = try await IndyWallet.generateKey(forConfig:"{\"seed\":\"\(seed)\"}")
            return key
        } catch {
            logger.error("wallet key generation failed. \(error.localizedDescription)")
            throw error
        }
        return nil
    }

    
    func getGenesisTxnURLs() -> [URL] {
        logger.debug("listing genesis txn urls.")
        let networks = Bundle.main.urls(forResourcesWithExtension:"json", subdirectory:"networks")!
        logger.debug("networks:")
        for (index, url) in networks.enumerated() {
            let networkName = url.lastPathComponent
            logger.debug(" * [\(index)] \(networkName)")
        }
        return networks.sorted { $0.lastPathComponent < $1.lastPathComponent }
    }
    
    func provisionAndStart() async throws {
        do {
            var agentConfig = getDefaultAgentConfig()
            agentConfig.walletId = walletIdForSelectedNetwork!
            agentConfig.walletKey = try await walletKeyFromSeed()!
            agentConfig.genesisPath = selectedNetwork!.absoluteURL.path
            
            logger.debug("agent provision with config=\(String(describing: agentConfig))")
            agent = Agent(agentConfig:agentConfig, agentDelegate:self)
            try await agent!.initialize()
            logger.debug("agent provisioned and initialized.")
            
            // Optional: you can save walletKey into Keychain
            // try KeychainHelper.standard.save(walletKey, service: "SampleWalletSwiftUI", account: config.walletId)
            
            try saveAgentConfigToPropertyList(config:agentConfig)
            
            logger.debug("agent ready.")
            self.isReady = agent!.isInitialized()
        } catch {
            throw ApplicationError.withMessage("agent provision and start failed.", error)
        }
    }
    
    func start() async throws {
        do {
            var agentConfig = try readAgentConfigFromPropertyList()
            agentConfig.walletKey = try await walletKeyFromSeed()!
            
            // Optional: you can read walletKey from Keychain
            // agentConfig.walletKey = KeychainHelper.standard.read(service: "SampleWalletSwiftUI", account: agentConfig.walletId)
            
            logger.debug("agent start with config=\(String(describing: agentConfig))")
            self.agent = Agent(agentConfig:agentConfig, agentDelegate:self)
            try await agent!.initialize()
            logger.debug("agent initialized.")
            
            logger.debug("agent ready.")
            self.isReady = agent!.isInitialized()
        }
        catch
        {
            throw ApplicationError.withMessage("agent start failed with unknown error.", error)
        }
    }
    
    func saveAgentConfigToPropertyList(config: AgentConfig) throws {
        let data = try PropertyListEncoder().encode(config)
        UserDefaults.standard.setValue(data, forKey:self.agentConfigIdForSelectedNetwork!)
        logger.debug("AgentConfig[\(self.agentConfigIdForSelectedNetwork!)] saved in plist.")
    }
    
    func readAgentConfigFromPropertyList() throws -> AgentConfig {
        let data = UserDefaults.standard.object(forKey: agentConfigIdForSelectedNetwork!) as? Data
        if (data == nil) {
            throw ApplicationError.withMessage("AgentConfig read failed")
        }
        let result = try PropertyListDecoder().decode(AgentConfig.self, from: data!)
        return result
    }
    
    func connectionReceiveInvitation() async throws -> ConnectionRecord {
        logger.info("receiveInvitationAsync begin")
        if self.connectionInvitation == "" {
            throw ApplicationError.withMessage("invitation was not received yet.")
        }
        do {
            let c = try await self.agent!.connections.receiveInvitationFromUrl(self.connectionInvitation)
            self.connectionInvitation = ""
            try await connectionsUpdate()
            logger.info("receiveInvitationAsync end")
            return c
        } catch {
            throw error
        }
    }
    
    func connectionsUpdate() async throws {
        if let list = await agent?.connectionRepository.getAll() {
            self.connectionList = list
        }
    }
    
    func credentialsUpdate() async throws {
        do {
            if let credentialsJson = try await IndyAnoncreds.proverGetCredentials(forFilter: "{}", walletHandle: agent!.wallet.handle!) {
                self.credentials = try! JSONDecoder().decode([CredentialRecord].self, from: credentialsJson.data(using: .utf8)!)
            }
        }
    }
    
    func oobReceiveInvitationFromUrl(_ url: String, config: ReceiveOutOfBandInvitationConfig? = nil) async throws -> (OutOfBandRecord?, ConnectionRecord?) {
        return try await self.agent!.oob.receiveInvitationFromUrl(url, config: config);
    }
    
    public func oobReceiveInvitation(url: String) async throws {
        let (_, _) = try await agent!.oob.receiveInvitationFromUrl(url)
    }

    var credentialRecordId = ""
    var proofRecordId = ""

    func processCredentialOffer() {
        confirmMessage = "Accept credential?"
        triggerAlert(type: .credOffer)
    }

    func processVerify() {
        confirmMessage = "Present proof?"
        triggerAlert(type: .proofRequest)
    }

    func getCredential() {
        menu = .loading

        Task {
            do {
                _ = try await agent!.credentials.acceptOffer(options: AcceptOfferOptions(credentialRecordId: credentialRecordId, autoAcceptCredential: .always))
            } catch {
                menu = nil
                showSimpleAlert(message: "Failed to receive credential")
                print(error)
            }
        }
    }

    func sendProof() {
        menu = .loading

        Task {
            do {
                let retrievedCredentials = try await agent!.proofs.getRequestedCredentialsForProofRequest(proofRecordId: proofRecordId)
                let requestedCredentials = try await agent!.proofService.autoSelectCredentialsForProofRequest(retrievedCredentials: retrievedCredentials)
                _ = try await agent!.proofs.acceptRequest(proofRecordId: proofRecordId, requestedCredentials: requestedCredentials)
            } catch {
                menu = nil
                showSimpleAlert(message: "Failed to present proof")
                print(error)
            }
        }
    }

    func reportError() {
        showSimpleAlert(message: "Invalid invitation url")
    }

    func triggerAlert(type: ActionType) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) { [weak self] in
            self?.actionType = type
        }
    }

    func showSimpleAlert(message: String) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) { [weak self] in
            self?.alertMessage = message
            self?.showAlert = true
        }
    }
}
