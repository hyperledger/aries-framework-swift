
import Foundation
import Criollo
@testable import AriesFramework

struct ProofResponse: Codable {
    let state: ProofState
    let threadId: String

    enum CodingKeys: String, CodingKey {
        case state, threadId = "thread_id"
    }
}
class PresentProofController: CRRouteController {
    var agent: Agent? {
        return TestHarnessConfig.shared.agent
    }

    override init(prefix: String) {
        super.init(prefix: prefix)

        self.get("/:threadId") { (req, res, next) in
            Task {
                do {
                    let threadId = req.query["threadId"]!
                    let record = try await self.agent!.proofRepository.getByThreadAndConnectionId(threadId: threadId, connectionId: nil)
                    ControllerUtils.send(res: res, data: self.mapProofRecord(record))
                } catch {
                    print("Error: \(error)")
                    res.setStatusCode(404, description: "Proof record not found")
                    ControllerUtils.sendEmptyResponse(res: res)
                }
            }
        }

        self.get("/") { (req, res, next) in
            Task {
                let records = try await self.agent!.proofRepository.getAll()
                ControllerUtils.send(res: res, data: records.map { self.mapProofRecord($0) })
            }
        }

        self.post("/send-presentation") { (req, res, next) in
            Task {
                do {
                    let body = req.body as? [String: Any]
                    guard let threadId = body?["id"] as? String else {
                        throw AriesFrameworkError.frameworkError("Cannot parse id from request body")
                    }
                    var record = try await self.agent!.proofRepository.getByThreadAndConnectionId(threadId: threadId, connectionId: nil)

                    let retrievedCredentials = try await self.agent!.proofs.getRequestedCredentialsForProofRequest(proofRecordId: record.id)
                    let requestedCredentials = try await self.agent!.proofService.autoSelectCredentialsForProofRequest(retrievedCredentials: retrievedCredentials)
                    record = try await self.agent!.proofs.acceptRequest(proofRecordId: record.id, requestedCredentials: requestedCredentials)
                    ControllerUtils.send(res: res, data: self.mapProofRecord(record))
                } catch {
                    print("Error: \(error)")
                    res.setStatusCode(500, description: "Send presentation failed")
                    ControllerUtils.sendEmptyResponse(res: res)
                }
            }
        }
    }

    func mapProofRecord(_ proof: ProofExchangeRecord) -> ProofResponse {
        return ProofResponse(state: proof.state, threadId: proof.threadId)
    }
}
