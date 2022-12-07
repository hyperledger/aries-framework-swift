
@testable import AriesFramework

class TestHarnessConfig {
    let backchannelPort = 9030
    let agentPort = 9031
    var agent: Agent?
    static let shared = TestHarnessConfig()

    private init() {}

    func startAgent() async throws {
        let name = "AFS TestHarness"
        let key = "HfyxAyKK8Z2xVzWbXXy2erY32B9Bnr8WFgR5HfzjAnGx"
        guard let genesisPath = Bundle(for: TestHelper.self).path(forResource: "bcovrin-genesis", ofType: "txn") else {
            throw AriesFrameworkError.frameworkError("Cannot find bcovrin-genesis.txn")
        }
        let config = AgentConfig(walletId: "AFSTestWallet: \(name)",
            walletKey: key,
            genesisPath: genesisPath,
            poolName: "AFSTestPool: \(name)",
            label: "Agent: \(name)",
            autoAcceptCredential: .never,
            autoAcceptProof: .never,
            useLegacyDidSovPrefix: true,
            publicDidSeed: "000000000000000000000000Trustee1",
            agentEndpoints: ["http://host.docker.internal:\(agentPort)"])

        agent = Agent(agentConfig: config, agentDelegate: nil)
        try await agent!.initialize()
    }

    func stopAgent() async throws {
        try await agent?.shutdown()
    }

    func prepareAgent() async throws {
        try await startAgent()
    }
}
