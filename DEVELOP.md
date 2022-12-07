# Framework Development Guide

## Depencencies

### Indy SDK

[Indy SDK](https://github.com/hyperledger/indy-sdk) is the most important library for Aries Framework Swift. It provides the following functions:
- DID management
- Credential and proof management
- Encryption/Decryption of messages
- Storage of data

We use the forked version of [iOS wrapper](https://github.com/hyperledger/indy-sdk/tree/main/wrappers/ios) of Indy SDK to support Swift and to fix dependency issues such as OpenSSL. Because Indy SDK is available only as a CocoaPods pod, we distribute Aries Framework Swift through CocoaPods. The [forked repo](https://github.com/naver/indy-sdk) of Indy SDK is also used as the base of podspecs.

### Other libraries

- [WebSockets](https://github.com/bhsw/concurrent-ws): Provides WebSocket API used in `WsOutboundTransport`. This library requires iOS 15.0+.
- [CollectionConcurrencyKit](https://github.com/JohnSundell/CollectionConcurrencyKit): Provides concurrent map APIs used in `ProofService` and `RevocationService`.
- [BigInt](https://github.com/attaswift/BigInt): Provides big interger types used in the `CredentialValues` struct to encode credential attributes as big integers. Note that `BigInt` is in the dependency of `Base58Swift`.
- [Base58Swift](https://github.com/keefertaylor/Base58Swift): Provides Base58 encoding/decoding used in `DIDParser` to handle [did:key](https://w3c-ccg.github.io/did-method-key/) in out-of-band invitation.
- [Criollo](https://github.com/thecatalinstan/Criollo): Provides HTTP server that can be used in unit tests. We use this library to implement a backchannel for [AATH](https://github.com/hyperledger/aries-agent-test-harness).

WebSockets and CollectionConcurrencyKit are distributed only as Swift packages, so we made CocoaPods podspecs for them in our private [Spec repo](https://github.com/naver/indy-sdk/tree/master/Specs).

## Framework Internals

Aries Framework Swift refers to [Aries Framework JavaScript](https://github.com/hyperledger/aries-framework-javascript) a lot, so the structure is similar to it.

### Agent

Agent is the main class of Aries Framework Swift. Mobile apps will use this class to create a connection, receive a credential, and so on. It helps mobile apps to become Aries agents. Agent class holds all the commands, services, repositories, and wallet instances. Agent also has a message sender and a receiver along with a dispatcher. Dispatcher dispatches messages to the corresponding `MessageHandler` by its type and sends the outbound messages back when the message handlers return them.

Aries Framework Swift only provides outbound transports, not inbound transports. It provides `HttpOutboundTransport` and `WsOutboundTransport` for HTTP and WebSocket, respectively. Agent selects the outbound transport automatically by the endpoint of the counterparty agent. HTTP outbound transport can be used when the agent uses a mediator. WebSocket outbound transport can be used with or without a mediator. `SubjectOutboundTransport` is for testing.

### Repository and Records

Repository classes provide APIs to store and retrieve records. The operation is done using Indy SDK which uses sqlite as a storage. Records can have custom tags and can be searched by the tags.

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
- AriesFrameworkTests: This is the default test plan. We can run it without any setup and it will finish in a second.
- AllTests: This is the test plan for all the tests including credential tests, proof tests, and out-of-band tests. We need a local indy pool to run this test plan.
- AgentTest: This test requires other agents to run. We run this test manually one by one.
- AATHTest: This test is for AATH. See below for more details.

### AllTests preparation

`AllTests` plan requires a local indy pool. We need Docker Desktop or colima to run the pool.

```bash
$ git clone https://github.com/naver/indy-sdk.git
$ cd indy-sdk
$ docker build -f ci/indy-pool.dockerfile -t indy_pool .
$ docker run -itd -p 9701-9708:9701-9708 indy_pool
```

Select `AriesFrameworkTests` scheme in XCode, select `AllTests` test plan in Test navigator and run the tests. You also can run it from the command line.

```bash
$ xcodebuild test -workspace AriesFramework.xcworkspace -scheme AriesFrameworkTests -destination 'platform=iOS Simulator,name=iPhone 14 Pro' -testPlan AllTests | xcpretty
``` 

### AgentTest preparation

`AgentTest` requires a mediator and another agent to offer credentials. We use Aries Framework Javascript for this purpose.

First, we need to install Indy SDK on Mac.
```bash
$ brew tap conanoc/libindy
$ brew install --build-from-source libindy
```

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

### AATHTest preparation

`AATHTest` is a test for [Aries Agent Test Harness](https://github.com/hyperledger/aries-agent-test-harness). There is a [forked repo](https://github.com/conanoc/aries-agent-test-harness) to run AATH with Aries Framework Swift. We run other agents in a docker environment and run `AATHTest` in a simulator.

We need docker runtime such as Docker Desktop or colima to run AATH. And add the following line to `/etc/hosts` file.
```
127.0.0.1 host.docker.internal
```

Then, Run the steps below:
```bash
$ git clone https://github.com/conanoc/aries-agent-test-harness.git
$ git checkout local_run
$ cd aries-agent-test-harness
$ ./manage build -a acapy -a javascript
$ LEDGER_URL_CONFIG=http://test.bcovrin.vonx.io TAILS_SERVER_URL_CONFIG=https://tails.vonx.io ./manage run -d acapy -b local -t @AIP10 -t ~@wip
```

Now, you can run `AATHTest` in Xcode. `AATHTest` awaits for 20 min acting as a Bob agent. You can run a single AATH test like this:
```bash
# Run javascript agent as Alice and AATHTest as Bob for T003-RFC0036
$ LEDGER_URL_CONFIG=http://test.bcovrin.vonx.io TAILS_SERVER_URL_CONFIG=https://tails.vonx.io ./manage run -a javascript -b local -t @T003-RFC0036
```

### Testing using the sample app

You can test the sample app with modified AriesFramework by changing the Podfile and podspec file.

Change Sample/Podfile:
```diff
-  pod 'AriesFramework', '~> 1.0'
+  pod 'AriesFramework', :path => '../AriesFramework.podspec'
```

Change AriesFramework.podspec:
```diff
-  spec.source       = { :git => "https://github.com/naver/aries-framework-swift.git", :tag => 'v1.0.0' }
+  spec.source       = { :git => "" }
```

Then, run `pod install` in `Sample` directory. AriesFramework will be included as `Development Pods` in the sample app's Pods and the changes in the AriesFramework is applied automatically.
