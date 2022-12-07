
import Foundation
import Criollo
import Indy
@testable import AriesFramework

struct CredentialResponse: Codable {
    let state: CredentialState
    let credentialId: String?
    let threadId: String

    enum CodingKeys: String, CodingKey {
        case state, credentialId = "credential_id", threadId = "thread_id"
    }
}

struct ProposeRequest: Codable {
    let data: Proposal
}

struct Proposal: Codable {
    let connectionId: String
    let credentialProposal: CredentialPreview?
    let schemaId: String?
    let schemaIssuerDid: String?
    let schemaName: String?
    let schemaVersion: String?
    let credentialDefinitionId: String?
    let issuerDid: String?

    enum CodingKeys: String, CodingKey {
        case connectionId = "connection_id", credentialProposal = "credential_proposal", schemaId = "schema_id", schemaIssuerDid = "schema_issuer_did", schemaName = "schema_name", schemaVersion = "schema_version", credentialDefinitionId = "cred_def_id", issuerDid = "issuer_did"
    }
}

class IssueCredentialController: CRRouteController {
    var agent: Agent? {
        return TestHarnessConfig.shared.agent
    }

    override init(prefix: String) {
        super.init(prefix: prefix)

        self.get("/:threadId") { (req, res, next) in
            Task {
                let id = req.query["threadId"]!
                let credential = try await self.agent!.credentialRepository.getByThreadAndConnectionId(threadId: id, connectionId: nil)
                ControllerUtils.send(res: res, data: self.mapCredential(credential))
            }
        }

        self.get("/") { (req, res, next) in
            Task {
                let credentials = try await self.agent!.credentialRepository.getAll()
                ControllerUtils.send(res: res, data: credentials.map { self.mapCredential($0) })
            }
        }

        self.post("/send-proposal") { (req, res, next) in
            Task {
                do {
                    let data = try JSONSerialization.data(withJSONObject: req.body!, options: [])
                    let requestBody = try JSONDecoder().decode(ProposeRequest.self, from: data)
                    let request = requestBody.data
                    let connection = try await self.agent!.connectionRepository.getById(request.connectionId)
                    let options = CreateProposalOptions(connection: connection,
                                                        credentialPreview: request.credentialProposal,
                                                        schemaIssuerDid: request.schemaIssuerDid,
                                                        schemaId: request.schemaId,
                                                        schemaName: request.schemaName,
                                                        schemaVersion: request.schemaVersion,
                                                        credentialDefinitionId: request.credentialDefinitionId,
                                                        issuerDid: request.issuerDid)
                    let credential = try await self.agent!.credentials.proposeCredential(options: options)
                    ControllerUtils.send(res: res, data: self.mapCredential(credential))
                } catch {
                    print("Error: \(error)")
                    res.setStatusCode(500, description: "Cannot send proposal")
                    ControllerUtils.sendEmptyResponse(res: res)
                }
            }
        }

        self.post("/send-offer") { (req, res, next) in
            res.setStatusCode(501, description: "Not Implemented")
            ControllerUtils.sendEmptyResponse(res: res)
        }

        self.post("/issue") { (req, res, next) in
            res.setStatusCode(501, description: "Not Implemented")
            ControllerUtils.sendEmptyResponse(res: res)
        }

        self.post("/send-request") { (req, res, next) in
            Task {
                do {
                    let body = req.body as? [String: Any]
                    guard let id = body?["id"] as? String else {
                        throw AriesFrameworkError.frameworkError("Cannot parse id from request body")
                    }
                    var credential = try await self.agent!.credentialRepository.getByThreadAndConnectionId(threadId: id, connectionId: nil)
                    credential = try await self.agent!.credentials.acceptOffer(options: AcceptOfferOptions(credentialRecordId: credential.id))
                    ControllerUtils.send(res: res, data: self.mapCredential(credential))
                } catch {
                    print(error)
                    res.setStatusCode(500, description: error.localizedDescription)
                    ControllerUtils.sendEmptyResponse(res: res)
                }
            }
        }

        self.post("/store") { (req, res, next) in
            Task {
                do {
                    let body = req.body as? [String: Any]
                    guard let id = body?["id"] as? String else {
                        throw AriesFrameworkError.frameworkError("Cannot parse id from request body")
                    }
                    var credential = try await self.agent!.credentialRepository.getByThreadAndConnectionId(threadId: id, connectionId: nil)
                    credential = try await self.agent!.credentials.acceptCredential(options: AcceptCredentialOptions(credentialRecordId: credential.id))
                    ControllerUtils.send(res: res, data: self.mapCredential(credential))
                } catch {
                    print(error)
                    res.setStatusCode(500, description: error.localizedDescription)
                    ControllerUtils.sendEmptyResponse(res: res)
                }
            }
        }
    }

    func mapCredential(_ credentialRecord: CredentialExchangeRecord) -> CredentialResponse {
        let credentialId = credentialRecord.credentials.first?.credentialRecordId
        return CredentialResponse(state: credentialRecord.state, credentialId: credentialId, threadId: credentialRecord.threadId)
    }
}
