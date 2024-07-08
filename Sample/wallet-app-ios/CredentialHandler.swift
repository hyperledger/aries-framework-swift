//
//  RequestHandler.swift
//  wallet-app-ios
//

import SwiftUI
import AriesFramework

enum ActionType: Identifiable {
    case credOffer, proofRequest
    var id: Int {
        hashValue
    }
}

extension Data {
    func string() -> String {
        return String(decoding: self, as: UTF8.self)
    }
}

extension CredentialHandler: AgentDelegate {
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
        } else if proofRecord.state == .PresentationReceived {
            menu = nil
            showSimpleAlert(message: "Proof.isVerified: \(proofRecord.isVerified!)")
        } else if proofRecord.state == .PresentationSent {
            menu = nil
            showSimpleAlert(message: "Proof sent")
        }
    }
}

@MainActor class CredentialHandler: ObservableObject {
    static let shared = CredentialHandler()
    @Published var confirmMessage = ""
    @Published var actionType: ActionType?
    @Published var alertMessage = ""
    @Published var showAlert = false
    @Published var menu: MainMenu?

    var credentialRecordId = ""
    var proofRecordId = ""

    private init() {}

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
                showSimpleAlert(message: "Failed to present proof: \(error)")
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

    func createProofInvitation() async throws -> String {
        let attributes = ["attrbutes1": ProofAttributeInfo(names: ["name", "degree"])]
        let nonce = try ProofService.generateProofRequestNonce()
        let proofRequest = ProofRequest(nonce: nonce, requestedAttributes: attributes, requestedPredicates: [:])
        let (message, _) = try await agent!.proofService.createRequest(proofRequest: proofRequest)
        let outOfBandRecord = try await agent!.oob.createInvitation(
            config: CreateOutOfBandInvitationConfig(handshake: false, messages: [message]))
        let invitation = outOfBandRecord.outOfBandInvitation
        return try invitation.toUrl(domain: "http://example.com")
    }
}
