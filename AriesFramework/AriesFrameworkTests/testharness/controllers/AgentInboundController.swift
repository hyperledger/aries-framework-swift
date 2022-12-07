
import Foundation
import Criollo
@testable import AriesFramework

class AgentInboundController: CRRouteController {
    var agent: Agent? {
        return TestHarnessConfig.shared.agent
    }

    override init(prefix: String) {
        super.init(prefix: prefix)

        self.post("/") { (req, res, next) in
            Task {
                print("Got message from agentInbound")
                if self.agent == nil {
                    res.setStatusCode(500, description: "Agent not started")
                    res.send("Agent not started")
                    return
                }

                if let file = req.files?["0"]?.temporaryFileURL {
                    let data = try Data(contentsOf: file)
                    let encryptedMessage = try JSONDecoder().decode(EncryptedMessage.self, from: data)
                    try await self.agent!.receiveMessage(encryptedMessage)
                    ControllerUtils.sendEmptyResponse(res: res)
                    return
                }

                // swiftlint:disable:next force_cast
                let encryptedMessage = try JSONDecoder().decode(EncryptedMessage.self, from: req.body as! Data)
                try await self.agent!.receiveMessage(encryptedMessage)
                ControllerUtils.sendEmptyResponse(res: res)
            }
        }
    }
}
