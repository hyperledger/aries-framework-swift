
import Foundation
import os

class MediationRecipient {
    let logger = Logger(subsystem: "AriesFramework", category: "MediationRecipient")
    let mediationWaiter = AsyncWaiter()
    let keylistWaiter = AsyncWaiter()
    let agent: Agent
    let repository: MediationRepository
    var keylistUpdateDone = false
    var pickupTimer: Timer?

    init(agent: Agent, dispatcher: Dispatcher) {
        self.agent = agent
        self.repository = MediationRepository(agent: agent)
        registerHandlers(dispatcher: dispatcher)
    }

    func registerHandlers(dispatcher: Dispatcher) {
        dispatcher.registerHandler(handler: MediationGrantHandler(agent: agent))
        dispatcher.registerHandler(handler: MediationDenyHandler(agent: agent))
        dispatcher.registerHandler(handler: BatchHandler(agent: agent))
        dispatcher.registerHandler(handler: KeylistUpdateResponseHandler(agent: agent))
    }

    func initialize(mediatorConnectionsInvite: String) async throws {
        logger.debug("Initialize mediation with invitation: \(mediatorConnectionsInvite)")
        let type = OutOfBandInvitation.getInvitationType(url: mediatorConnectionsInvite)
        var recipientKey: String?
        var invitation: ConnectionInvitationMessage?
        var outOfBandInvitation: OutOfBandInvitation?
        switch type {
        case .Connection:
            invitation = try ConnectionInvitationMessage.fromUrl(mediatorConnectionsInvite)
            recipientKey = invitation!.recipientKeys?.first
        case .OOB:
            outOfBandInvitation = try OutOfBandInvitation.fromUrl(mediatorConnectionsInvite)
            recipientKey = try outOfBandInvitation!.invitationKey()
        default:
            throw AriesFrameworkError.frameworkError("Unsupported invitation message: \(mediatorConnectionsInvite)")
        }

        guard let recipientKey = recipientKey else {
            throw AriesFrameworkError.frameworkError("Invalid mediation invitation. Invitation must have at least one recipient key.")
        }

        if let connection = await agent.connectionService.findByInvitationKey(recipientKey), connection.isReady() {
            try await requestMediationIfNecessry(connection: connection)
        } else {
            let connection = try await agent.connectionService.processInvitation(invitation,
                outOfBandInvitation: outOfBandInvitation, routing: self.getRouting(), autoAcceptConnection: true)
            let message = try await agent.connectionService.createRequest(connectionId: connection.id)
            try await agent.messageSender.send(message: message)

            if try await agent.connectionService.fetchState(connectionRecord: connection) != .Complete {
                let result = try await agent.connectionService.waitForConnection()
                if !result {
                    throw AriesFrameworkError.frameworkError("Connection to the mediator timed out.")
                }
            }
            try await requestMediationIfNecessry(connection: connection)
        }
    }

    func close() {
        pickupTimer?.invalidate()
    }

    func requestMediationIfNecessry(connection: ConnectionRecord) async throws {
        if let mediationRecord = try await repository.getDefault() {
            if mediationRecord.isReady() && hasSameInvitationUrl(record: mediationRecord) {
                try await initiateMessagePickup(mediator: mediationRecord)
                agent.setInitialized()
                return
            }

            try await repository.delete(mediationRecord)
        }

        // If mediation request has not been done yet, start it.
        let message = try await createRequest(connection: connection)
        try await agent.messageSender.send(message: message)

        var mediationRecord = try await repository.getByConnectionId(connection.id)
        if mediationRecord.state == .Requested {
            let result = try await mediationWaiter.wait()
            if !result {
                throw AriesFrameworkError.frameworkError("Mediation request timed out.")
            }
        }
        mediationRecord = try await repository.getByConnectionId(connection.id)
        if mediationRecord.state == .Denied {
            throw AriesFrameworkError.frameworkError("Mediation request denied.")
        }
        try mediationRecord.assertReady()
    }

    func hasSameInvitationUrl(record: MediationRecord) -> Bool {
        return record.invitationUrl == agent.agentConfig.mediatorConnectionsInvite
    }

    func initiateMessagePickup(mediator: MediationRecord) async throws {
        let mediatorConnection = try await agent.connectionRepository.getById(mediator.connectionId)
        try await self.pickupMessages(mediatorConnection: mediatorConnection)

        DispatchQueue.main.async {
            self.pickupTimer = Timer.scheduledTimer(withTimeInterval: self.agent.agentConfig.mediatorPollingInterval, repeats: true) { [self] timer in
                Task {
                    try await self.pickupMessages(mediatorConnection: mediatorConnection)
                }
            }
        }
    }

    func pickupMessages(mediatorConnection: ConnectionRecord) async throws {
        try mediatorConnection.assertReady()

        if agent.agentConfig.mediatorPickupStrategy == .PickUpV1 {
            let message = OutboundMessage(payload: BatchPickupMessage(batchSize: 10), connection: mediatorConnection)
            try await agent.messageSender.send(message: message)
        } else if agent.agentConfig.mediatorPickupStrategy == .Implicit {
            let message = OutboundMessage(payload: TrustPingMessage(comment: "pickup", responseRequested: false), connection: mediatorConnection)
            try await agent.messageSender.send(message: message, endpointPrefix: "ws")
        } else {
            throw AriesFrameworkError.frameworkError("Unsupported mediator pickup strategy: \(agent.agentConfig.mediatorPickupStrategy)")
        }
    }

    func pickupMessages() async throws {
        guard let mediator = try await repository.getDefault() else {
            throw AriesFrameworkError.frameworkError("Mediator is not ready.")
        }
        let mediatorConnection = try await agent.connectionRepository.getById(mediator.connectionId)
        try await pickupMessages(mediatorConnection: mediatorConnection)
    }

    func getRouting() async throws -> Routing {
        let mediator = try await repository.getDefault()
        let endpoints = mediator?.endpoint == nil ? agent.agentConfig.endpoints : [mediator!.endpoint!]
        let routingKeys = mediator?.routingKeys ?? []

        let (did, verkey) = try await agent.wallet.createDid()
        if mediator != nil && mediator!.isReady() {
            try await keylistUpdate(mediator: mediator!, verkey: verkey)
        }

        return Routing(endpoints: endpoints, verkey: verkey, did: did, routingKeys: routingKeys, mediatorId: mediator?.id)
    }

    func createRequest(connection: ConnectionRecord) async throws -> OutboundMessage {
        let message = MediationRequestMessage(sentTime: Date())
        let mediationRecord = MediationRecord(state: .Requested, role: .Mediator, connectionId: connection.id, threadId: connection.id, invitationUrl: agent.agentConfig.mediatorConnectionsInvite!)
        try await repository.save(mediationRecord)

        return OutboundMessage(payload: message, connection: connection)
    }

    func processMediationGrant(messageContext: InboundMessageContext) async throws {
        let connection = try messageContext.assertReadyConnection()
        var mediationRecord = try await repository.getByConnectionId(connection.id)
        let decoder = JSONDecoder()
        let message = try decoder.decode(MediationGrantMessage.self, from: Data(messageContext.plaintextMessage.utf8))

        try mediationRecord.assertState(.Requested)

        mediationRecord.endpoint = message.endpoint
        mediationRecord.routingKeys = message.routingKeys
        mediationRecord.state = .Granted
        try await repository.update(mediationRecord)
        agent.agentDelegate?.onMediationStateChanged(mediationRecord: mediationRecord)
        agent.setInitialized()
        mediationWaiter.finish()
        try await initiateMessagePickup(mediator: mediationRecord)
    }

    func processMediationDeny(messageContext: InboundMessageContext) async throws {
        let connection = try messageContext.assertReadyConnection()
        var mediationRecord = try await repository.getByConnectionId(connection.id)
        try mediationRecord.assertState(.Requested)

        mediationRecord.state = .Denied
        try await repository.update(mediationRecord)
        agent.agentDelegate?.onMediationStateChanged(mediationRecord: mediationRecord)
        mediationWaiter.finish()
    }

    func processBatchMessage(messageContext: InboundMessageContext) async throws {
        if messageContext.connection == nil {
            throw AriesFrameworkError.frameworkError("No connection associated with incoming message with id \(messageContext.message.id)")
        }

        let decoder = JSONDecoder()
        let message = try decoder.decode(BatchMessage.self, from: Data(messageContext.plaintextMessage.utf8))

        logger.debug("Get \(message.messages.count) batch messages")
        let forwardedMessages = message.messages
        for forwardedMessage in forwardedMessages {
            try await agent.receiveMessage(forwardedMessage.message)
        }
    }

    func processKeylistUpdateResults(messageContext: InboundMessageContext) async throws {
        let connection = try messageContext.assertReadyConnection()
        let mediationRecord = try await repository.getByConnectionId(connection.id)
        try mediationRecord.assertReady()

        let decoder = JSONDecoder()
        let message = try decoder.decode(KeylistUpdateResponseMessage.self, from: Data(messageContext.plaintextMessage.utf8))
        for update in message.updated {
            if update.action == .add {
                logger.info("Key \(update.recipientKey) added to keylist")
            } else if update.action == .remove {
                logger.info("Key \(update.recipientKey) removed from keylist")
            }
        }
        keylistUpdateDone = true
        keylistWaiter.finish()
    }

    func keylistUpdate(mediator: MediationRecord, verkey: String) async throws {
        try mediator.assertReady()
        let keylistUpdateMessage = KeylistUpdateMessage(updates: [KeylistUpdate(recipientKey: verkey, action: .add)])
        let connection = try await agent.connectionRepository.getById(mediator.connectionId)
        let message = OutboundMessage(payload: keylistUpdateMessage, connection: connection)

        keylistUpdateDone = false
        try await agent.messageSender.send(message: message)

        if !keylistUpdateDone {
            let result = try await keylistWaiter.wait()
            if !result {
                throw AriesFrameworkError.frameworkError("Keylist update timed out")
            }
        }
    }
}
