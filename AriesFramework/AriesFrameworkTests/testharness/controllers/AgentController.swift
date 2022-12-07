
import Foundation
import Criollo
@testable import AriesFramework

class AgentController: CRRouteController {
    override init(prefix: String) {
        super.init(prefix: prefix)

        self.post("/start") { (req, res, next) in
            Task {
                try await TestHarnessConfig.shared.stopAgent()
                try await TestHarnessConfig.shared.startAgent()
                ControllerUtils.sendEmptyResponse(res: res)
            }
        }
    }
}
