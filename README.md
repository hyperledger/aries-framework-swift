# Aries Framework Swift

Aries Framework Swift is an iOS framework for [Aries](https://github.com/hyperledger/aries) protocol.

## Features

Aries Framework Swift supports most of [AIP 1.0](https://github.com/hyperledger/aries-rfcs/tree/main/concepts/0302-aries-interop-profile#aries-interop-profile-version-10) features for mobile agents.

### Supported features
- ✅ ([RFC 0160](https://github.com/hyperledger/aries-rfcs/blob/master/features/0160-connection-protocol/README.md)) Connection Protocol
- ✅ ([RFC 0211](https://github.com/hyperledger/aries-rfcs/blob/master/features/0211-route-coordination/README.md)) Mediator Coordination Protocol
- ✅ ([RFC 0095](https://github.com/hyperledger/aries-rfcs/blob/master/features/0095-basic-message/README.md)) Basic Message Protocol
- ✅ ([RFC 0036](https://github.com/hyperledger/aries-rfcs/blob/master/features/0036-issue-credential/README.md)) Issue Credential Protocol
- ✅ ([RFC 0037](https://github.com/hyperledger/aries-rfcs/tree/master/features/0037-present-proof/README.md)) Present Proof Protocol
  - Does not implement alternate begining (Prover begins with proposal)
- ✅ HTTP, WebSocket and Bluetooth Transport
- ✅ ([RFC 0434](https://github.com/hyperledger/aries-rfcs/blob/main/features/0434-outofband/README.md)) Out of Band Protocol (AIP 2.0)
- ✅ ([RFC 0035](https://github.com/hyperledger/aries-rfcs/blob/main/features/0035-report-problem/README.md)) Report Problem Protocol
- ✅ ([RFC 0023](https://github.com/hyperledger/aries-rfcs/tree/main/features/0023-did-exchange)) DID Exchange Protocol (AIP 2.0)

### Not supported yet
- ❌ ([RFC 0056](https://github.com/hyperledger/aries-rfcs/blob/main/features/0056-service-decorator/README.md)) Service Decorator

## Requirements & Installation

Aries Framework Swift requires iOS 15.0+ and distributed as a Swift package.

Add a dependency to your `Package.swift` file:
```swift
dependencies: [
    .package(url: "https://github.com/hyperledger/aries-framework-swift", from: "2.5.0")
]
```

## Usage

App development using Aries Framework Swift is done in following steps:
1. Create an Agent instance
2. Create a connection with another agent by receiving a connection invitation
3. Receive credentials or proof requests by implementing a AgentDelegate

### Create an Agent instance

```swift
    import AriesFramework

    let config = AgentConfig(walletKey: key,
        genesisPath: genesisPath,
        mediatorConnectionsInvite: mediatorInvitationUrl,
        mediatorPickupStrategy: .Implicit,
        label: "SampleApp",
        autoAcceptCredential: .never,
        autoAcceptProof: .never)

    let agent = Agent(agentConfig: config, agentDelegate: myAgentDelegate)
    try await agent.initialize()
```

To create an agent, first create a key to encrypt the wallet and save it in the keychain.
```swift
    let key = try Agent.generateWalletKey()
```

A genesis file for the indy pool should be included as a resource in the app bundle and get the path to it.
```swift
    let genesisPath = Bundle.main.path(forResource: "genesis", ofType: "txn")
```

If you want to use a mediator, set the `mediatorConnectionsInvite` in the config.
`mediatorConnectionsInvite` is a url containing either a connection invitation or an out-of-band invitation.
`mediatorPickupStrategy` need to be `.Implicit` to connect to an ACA-Py mediator.

You can use WebSocket transport without a mediator, but you will need a mediator if the counterparty agent only supports http transport.

`agentDelegate` can be nil if you don't want to receive any events from the agent.

### Receive an invitation

Create a connection by receiving a connection invitation.
```swift
    let (_, connection) = try await agent.oob.receiveInvitationFromUrl(url)
```

You will generally get the invitation url by QR code scanning.
Once the connection is created, it is stored in the wallet and your counterparty agent can send you a credential or a proof request using the connection at any time. The connection record contains keys to encrypt or decrypt messages exchanged through the connection.

### Receive credentials or proof requests

Implement `AgentDelegate` to receive events from the agent and use `agent.credentials` or `agent.proofs` commands to handle the requests.

```swift
class MyAgentDelegate: AgentDelegate {
    func onCredentialStateChanged(credentialRecord: CredentialExchangeRecord) {
        if credentialRecord.state == .OfferReceived {
            processCredentialOffer(credentialRecord)
        } else if credentialRecord.state == .Done {
            showSimpleAlert(message: "Credential received")
        }
    }

    func onProofStateChanged(proofRecord: ProofExchangeRecord) {
        if proofRecord.state == .RequestReceived {
            processProofRequest(proofRecord)
        } else if proofRecord.state == .Done {
            showSimpleAlert(message: "Proof done")
        }
    }

    func processCredentialOffer(_ credentialRecord: CredentialExchangeRecord) {
        Task {
            do {
                _ = try await agent.credentials.acceptOffer(options: AcceptOfferOptions(credentialRecordId: credentialRecord.id, autoAcceptCredential: .always))
            } catch {
                showSimpleAlert(message: "Failed to receive credential")
                print(error)
            }
        }
    }

    func processProofRequest(_ proofRecord: ProofExchangeRecord) {
        Task {
            do {
                let retrievedCredentials = try await agent.proofs.getRequestedCredentialsForProofRequest(proofRecordId: proofRecord.id)
                let requestedCredentials = try await agent.proofService.autoSelectCredentialsForProofRequest(retrievedCredentials: retrievedCredentials)
                _ = try await agent!.proofs.acceptRequest(proofRecordId: proofRecord.id, requestedCredentials: requestedCredentials)
            } catch {
                showSimpleAlert(message: "Failed to present proof")
                print(error)
            }
        }
    }
}
```

If you set `autoAcceptCredential` and `autoAcceptProof` to `.always` in the config, it will be done automatically and you don't need to implement a delegate.

Another way to handle those requests is to implement your own `MessageHandler` class and register it to the agent.
```swift
    let messageHandler = MyOfferCredentialHandler()
    agent.dispatcher.registerHandler(handler: messageHandler)
```

## Bluetooth support

Aries Framework Swift supports phone to phone communication over Bluetooth.
You will need to add `NSBluetoothAlwaysUsageDescription` key to the info.plist of your app to use Bluetooth.

### How to use

Verifier side:
1. Call `try await agent.startBLE()` to create an endpoint over BLE. The endpoint has the form of "ble://aries/endpoint?uuid={uuid}".
2. Create an oob-invitation and create a QR code with the invitation url. This invitation will use the endpoint created above even though the agent has a mediator connection. You should create an oob-invitation attaching a proof request message without handshake option. This allows the prover sends the proof directly to the verifier without preparing any endpoint.
```swift
let oob = try await agent!.oob.createInvitation(config: CreateOutOfBandInvitationConfig(handshake: false, messages: [message]))
let invitationUrl = oob.outOfBandInvitation.toUrl(domain: "http://example.com")
```
3. Call `try? await agent.stopBLE()` after you finish verification.

Prover side:
- There is nothing you need to do to communicate over BLE on prover side. The agent will recognize the `ble://` scheme and connect to the verifier's device over BLE. The connection will be closed automatically after the message is sent.

The sample app has sample codes that demonstrates proof exchange over Bluetooth.

## Sample App

`Sample` directory contains an iOS sample app that demonstrates how to use Aries Framework Swift. The app receives a connection invitation from a QR code or from a URL input and handles credential offers and proof requests.

The agent is created in the `WalletOpener.swift` file and you can set a mediator connection invitation url there, if you want.

There are two genesis files in the `resources` directory.
- `bcovrin-genesis.txn` is for the [GreenLight Dev Ledger](http://dev.greenlight.bcovrin.vonx.io/)
- `local-genesis.txn` is for the local indy-pool.

## Contributing

We welcome contributions to Aries Framework Swift. Please see our [Developer Guide](DEVELOP.md) for more information.

## License

Aries Framework Swift is licensed under the [Apache License 2.0](LICENSE).
