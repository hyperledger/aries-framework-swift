
import Foundation
import Criollo
@testable import AriesFramework

class OutOfBandController: CRRouteController {
    override init(prefix: String) {
        super.init(prefix: prefix)

        self.post("/[a-z-]+") { (req, res, next) in
            res.setStatusCode(501, description: "Not Implemented")
            ControllerUtils.sendEmptyResponse(res: res)
        }
    }
}
