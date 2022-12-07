// swiftlint:disable cyclomatic_complexity

import Foundation
import Criollo
@testable import AriesFramework

struct ConnectionResponse: Codable {
    let state: String
    let connectionId: String
    let connection: ConnectionRecord

    enum CodingKeys: String, CodingKey {
        case state, connectionId = "connection_id", connection
    }
}

struct CreateInvitationResponse: Codable {
    let connectionId: String
    let invitation: ConnectionInvitationMessage

    enum CodingKeys: String, CodingKey {
        case connectionId = "connection_id", invitation
    }
}

struct ReceiveInvitationRequest: Codable {
    let data: ConnectionInvitationMessage
}

class ConnectionController: CRRouteController {
    var agent: Agent? {
        return TestHarnessConfig.shared.agent
    }

    override init(prefix: String) {
        super.init(prefix: prefix)

        self.get("/:id") { (req, res, next) in
            Task {
                do {
                    let id = req.query["id"]!
                    guard let connection = try await self.agent?.connectionRepository.findById(id) else {
                        res.setStatusCode(404, description: "Connection not found")
                        ControllerUtils.sendEmptyResponse(res: res)
                        return
                    }
                    ControllerUtils.send(res: res, data: self.mapConnection(connection))
                } catch {
                    print("Error: \(error)")
                    res.setStatusCode(404, description: "Connection not found")
                    ControllerUtils.sendEmptyResponse(res: res)
                }
            }
        }

        self.get("/") { (req, res, next) in
            Task {
                do {
                    let connections = try await self.agent?.connectionRepository.getAll()
                    ControllerUtils.send(res: res, data: connections?.map { self.mapConnection($0) })
                } catch {
                    print("Error: \(error)")
                    res.setStatusCode(500, description: "Cannot get connections")
                    ControllerUtils.sendEmptyResponse(res: res)
                }
            }
        }

        self.post("/create-invitation") { (req, res, next) in
            Task {
                do {
                    let message = try await self.agent!.connections.createConnection()
                    // swiftlint:disable:next force_cast
                    ControllerUtils.send(res: res, data: CreateInvitationResponse(connectionId: message.connection.id, invitation: message.payload as! ConnectionInvitationMessage))
                } catch {
                    print("Error: \(error)")
                    res.setStatusCode(500, description: "Cannot create invitation")
                    ControllerUtils.sendEmptyResponse(res: res)
                }
            }
        }

        self.post("/receive-invitation") { (req, res, next) in
            Task {
                do {
                    let data = try JSONSerialization.data(withJSONObject: req.body!, options: [])
                    let request = try JSONDecoder().decode(ReceiveInvitationRequest.self, from: data)
                    let connection = try await self.agent!.connections.receiveInvitation(request.data)
                    ControllerUtils.send(res: res, data: self.mapConnection(connection))
                } catch {
                    print("Error: \(error)")
                    res.setStatusCode(500, description: "Cannot receive invitation")
                    ControllerUtils.sendEmptyResponse(res: res)
                }
            }
        }

        self.post("/accept-invitation") { (req, res, next) in
            Task {
                do {
                    let body = req.body as? [String: Any]
                    guard let id = body?["id"] as? String else {
                        throw AriesFrameworkError.frameworkError("Cannot parse id from request body")
                    }
                    let connection = try await self.agent!.connectionRepository.getById(id)
                    ControllerUtils.send(res: res, data: self.mapConnection(connection))
                } catch {
                    print("Error: \(error)")
                    res.setStatusCode(500, description: "Cannot accept invitation")
                    ControllerUtils.sendEmptyResponse(res: res)
                }
            }
        }

        self.post("/accept-request") { (req, res, next) in
            Task {
                do {
                    let body = req.body as? [String: Any]
                    guard let id = body?["id"] as? String else {
                        throw AriesFrameworkError.frameworkError("Cannot parse id from request body")
                    }
                    let connection = try await self.agent!.connectionRepository.getById(id)
                    ControllerUtils.send(res: res, data: self.mapConnection(connection))
                } catch {
                    print("Error: \(error)")
                    res.setStatusCode(500, description: "Cannot accept request")
                    ControllerUtils.sendEmptyResponse(res: res)
                }
            }
        }

        // Already sent?
        self.post("/send-ping") { (req, res, next) in
            Task {
                do {
                    let body = req.body as? [String: Any]
                    guard let id = body?["id"] as? String else {
                        throw AriesFrameworkError.frameworkError("Cannot parse id from request body")
                    }
                    let connection = try await self.agent!.connectionRepository.getById(id)
                    ControllerUtils.send(res: res, data: self.mapConnection(connection))
                } catch {
                    print("Error: \(error)")
                    res.setStatusCode(500, description: "Cannot send ping")
                    ControllerUtils.sendEmptyResponse(res: res)
                }
            }
        }
    }

    func mapConnection(_ connection: ConnectionRecord) -> ConnectionResponse {
        return ConnectionResponse(
            state: connection.state == .Complete ? connection.state.rawValue : "N/A",
            connectionId: connection.id,
            connection: connection)
    }
}
