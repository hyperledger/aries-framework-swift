
import Foundation
import Criollo
import Indy
@testable import AriesFramework

class CredentialController: CRRouteController {
    var agent: Agent? {
        return TestHarnessConfig.shared.agent
    }

    override init(prefix: String) {
        super.init(prefix: prefix)

        self.get("/:credentialId") { (req, res, next) in
            Task {
                do {
                    let id = req.query["credentialId"]!
                    let credentialJson = try await IndyAnoncreds.proverGetCredential(withId: id, walletHandle: self.agent!.wallet.handle!)
                    ControllerUtils.send(res: res, json: credentialJson!)
                } catch {
                    res.setStatusCode(404, description: "Credential not found")
                    ControllerUtils.sendEmptyResponse(res: res)
                }
            }
        }
    }
}
