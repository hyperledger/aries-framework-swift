//
//  WalletOpener.swift
//  wallet-app-ios
//

import SwiftUI
import Indy
import AriesFramework

final class WalletState: ObservableObject {
  @Published var walletOpened: Bool = false
}

var agent: Agent?

class WalletOpener : ObservableObject {

    func openWallet(walletState: WalletState) async {
        let userDefaults = UserDefaults.standard
        var key = userDefaults.value(forKey:"walletKey") as? String
        if (key == nil) {
            do {
                key = try await IndyWallet.generateKey(forConfig: nil)
                userDefaults.set(key, forKey: "walletKey")
            } catch {
                if let err = error as NSError? {
                    print("Cannot generate key: \(err.userInfo["message"] ?? "Unknown error")")
                    return
                }
            }
        }

        let invitationUrl = "https://public.mediator.indiciotech.io?c_i=eyJAdHlwZSI6ICJkaWQ6c292OkJ6Q2JzTlloTXJqSGlxWkRUVUFTSGc7c3BlYy9jb25uZWN0aW9ucy8xLjAvaW52aXRhdGlvbiIsICJAaWQiOiAiMDVlYzM5NDItYTEyOS00YWE3LWEzZDQtYTJmNDgwYzNjZThhIiwgInNlcnZpY2VFbmRwb2ludCI6ICJodHRwczovL3B1YmxpYy5tZWRpYXRvci5pbmRpY2lvdGVjaC5pbyIsICJyZWNpcGllbnRLZXlzIjogWyJDc2dIQVpxSktuWlRmc3h0MmRIR3JjN3U2M3ljeFlEZ25RdEZMeFhpeDIzYiJdLCAibGFiZWwiOiAiSW5kaWNpbyBQdWJsaWMgTWVkaWF0b3IifQ=="
        let genesisPath = Bundle(for: WalletOpener.self).path(forResource: "bcovrin-genesis", ofType: "txn")
        let config = AgentConfig(walletKey: key!,
            genesisPath: genesisPath!,
            mediatorConnectionsInvite: invitationUrl,
            mediatorPickupStrategy: .Implicit,
            label: "SampleApp",
            autoAcceptCredential: .never,
            autoAcceptProof: .never)

        do {
            agent = Agent(agentConfig: config, agentDelegate: CredentialHandler.shared)
            try await agent!.initialize()
        } catch {
            print("Cannot initialize agent: \(error)")
            return
        }

        print("Wallet opened!")
        DispatchQueue.main.async {
            withAnimation { walletState.walletOpened = true }
        }
    }
}
