
import Foundation

public protocol AgentDelegate {
    func onConnectionStateChanged(connectionRecord: ConnectionRecord)
    func onMediationStateChanged(mediationRecord: MediationRecord)
    func onOutOfBandStateChanged(outOfBandRecord: OutOfBandRecord)
    func onCredentialStateChanged(credentialRecord: CredentialExchangeRecord)
    func onProofStateChanged(proofRecord: ProofExchangeRecord)
    func onProblemReportReceived(message: BaseProblemReportMessage)
}

// Default implementation of AgentDelegate
public extension AgentDelegate {
    func onConnectionStateChanged(connectionRecord: ConnectionRecord) {
    }

    func onMediationStateChanged(mediationRecord: MediationRecord) {
    }

    func onOutOfBandStateChanged(outOfBandRecord: OutOfBandRecord) {
    }

    func onCredentialStateChanged(credentialRecord: CredentialExchangeRecord) {
    }

    func onProofStateChanged(proofRecord: ProofExchangeRecord) {
    }

    func onProblemReportReceived(message: BaseProblemReportMessage) {
    }
}
