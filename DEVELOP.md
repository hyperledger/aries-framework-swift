# Framework Development Guide

## CI related

### Linting
We are using GitHub Actions for Lint check. See .github/workflows for details.
Run swiftlint at the root of the repo to check linting locally.

## Depencencies

- [aries-uniffi-wrappers](https://github.com/hyperledger/aries-uniffi-wrappers): Provides wrappers for three libraries, Aries Askar, AnonCreds and Indy VDR.
- [WebSockets](https://github.com/bhsw/concurrent-ws): Provides WebSocket API used in `WsOutboundTransport`. This library requires iOS 15.0+.
- [CollectionConcurrencyKit](https://github.com/JohnSundell/CollectionConcurrencyKit): Provides concurrent map APIs used in `ProofService` and `RevocationService`.
- [BigInt](https://github.com/attaswift/BigInt): Provides big interger types used in the `CredentialValues` struct to encode credential attributes as big integers. Note that `BigInt` is in the dependency of `Base58Swift`.
- [Base58Swift](https://github.com/keefertaylor/Base58Swift): Provides Base58 encoding/decoding used in `DIDParser` to handle [did:key](https://w3c-ccg.github.io/did-method-key/) in out-of-band invitation.
- [Criollo](https://github.com/thecatalinstan/Criollo): Provides HTTP server that can be used in unit tests. We use this library to implement a backchannel for [AATH](https://github.com/hyperledger/aries-agent-test-harness).

## Framework Internals

Aries Framework Swift refers to [Aries Framework JavaScript](https://github.com/hyperledger/aries-framework-javascript) a lot, so the structure is similar to it.

Take a look at the diagrams in the [doc](doc/dev_general.md) to understand the basics of Aries and the framework.

### Agent

Agent is the main class of Aries Framework Swift. Mobile apps will use this class to create a connection, receive a credential, and so on. It helps mobile apps to become Aries agents. Agent class holds all the commands, services, repositories, and wallet instances. Agent also has a message sender and a receiver along with a dispatcher. Dispatcher dispatches messages to the corresponding `MessageHandler` by its type and sends the outbound messages back when the message handlers return them.

Aries Framework Swift only provides outbound transports, not inbound transports. It provides `HttpOutboundTransport` and `WsOutboundTransport` for HTTP and WebSocket, respectively. Agent selects the outbound transport automatically by the endpoint of the counterparty agent. HTTP outbound transport can be used when the agent uses a mediator. WebSocket outbound transport can be used with or without a mediator. `SubjectOutboundTransport` is for testing.

### Repository and Records

Repository classes provide APIs to store and retrieve records. The operation is done using Aries Askar which uses sqlite as a storage. Records can have custom tags and can be searched by the tags.

### JSON encoding and decoding

Aries Framework Swift uses `Codable` protocol for JSON encoding and decoding. `AgentMessage` types, `BaseRecord` types, and model types used in these types should conform to `Codable` protocol. `AgentMessage` types are classes which inherit `Codable` class `AgentMessage`, so they should implement `encode(to: Encoder)` and `init(from: Decoder)` methods. `BaseRecord` types and other model types are structures, so they don't need to implement these methods.

### Connection

Aries agents make connections to exchange encrypted messages with each other. The connection here does not refer to the actual internet connection, but an information about the agents involved in the communication. `ConnectionRecord` is created through [Connection Protocol](https://github.com/hyperledger/aries-rfcs/tree/main/features/0160-connection-protocol) and contains data such as did, keys, endpoints, label, etc.

Aries agents find the existing connection by the keys in the message, so each connection must be created with a unique key. Agents know where to send messages by the endpoint stored in the connection records. Mobile agents using Aries Framework Swift do not have reachable endpoints, then how the counterpart agents can send messages to us? There are 2 solutions for this.
1. Using mediator. Agents use mediator's endpoints as their endpoints when creating a connection, then the messages for the agents will be sent to the mediator and agents can fetch the messages from the mediator later.
2. Using WebSocket and keep the WebSocket connection open. Agents using Aries Framework Javascript use the WebSocket session to send messages if the session is open, and they do not close the session when `return-route` is specified. This solution has limitations because the communication is possible only when the WebSocket session is open, and it's not guaranteed that other Aries Frameworks would not close the session. But, this could be a convenient solution depending on the situation.

### MediatoinRecipient

`AgentConfig.mediatorConnectionsInvite` is a connection invitation url from a mediator. An agent connects to the mediator when it is initialized. After the connection is made, it starts mediation protocol with the mediator. The mediation protocol is performed only once if successful, and the result is saved as an `MediationRecord`. `Agent.isInitialized()` becomes `true` when this process is done. Agents pick up messages from the mediator periodically.

Aries Framework Swift supports only one mediator. If the `AgentConfig.mediatorConnectionsInvite` is changed, agent will remove the existing `MediationRecord` and do the mediation protocol again.

### Transport Return Route

Agents can specify `return-route` for messages using the [transport decorator](https://github.com/hyperledger/aries-rfcs/tree/main/features/0092-transport-return-route). Aries Framework Swift is specifing `return-route` as `all` for all outbound messages in the `MessageSender` class.

## Testing

### XCode Unit Tests

There are several types of unit tests:
- BasicTests: This is the default test plan. We can run it without any setup and it will finish in a second.
- AllTests: This is the test plan for all the tests including credential tests, proof tests, and out-of-band tests. We need a local indy pool to run this test plan.
- AgentTest: This test requires other agents to run. We run this test manually one by one.

### AllTests preparation

`AllTests` plan requires a local indy pool. We need Docker Desktop or colima to run the pool.

```bash
$ git clone https://github.com/hyperledger/aries-framework-javascript.git
$ cd aries-framework-javascript
$ docker build -f network/indy-pool-arm.dockerfile -t indy_pool .
$ docker run -itd -p 9701-9708:9701-9708 indy_pool
```

Select `AriesFrameworkTests` scheme in XCode, select `AllTests` test plan in Test navigator and run the tests. You also can run it from the command line.

```bash
$ swift test --skip AgentTest | xcpretty
```

### AgentTest preparation

`AgentTest` requires a mediator and another agent to offer credentials. We use Aries Framework Javascript for this purpose.

Clone the Aries Framework Javascript repository.
```bash
git clone https://github.com/hyperledger/aries-framework-javascript.git
```

Build and run the mediator. It requires nodejs, yarn and npx.
```bash
$ cd aries-framework-javascript
$ yarn install
$ cd samples
$ npx ts-node mediator.ts
```

`testDemoFaber()` tests the credential exchange flow.
Run the faber agent in demo directory.
```bash
$ cd aries-framework-javascript/demo
$ yarn install
$ yarn faber
```

Then, get the invitation urls from the mediator and faber agent.
Run `testDemoFaber()` with these urls and operate the faber agent to issue a credential.
