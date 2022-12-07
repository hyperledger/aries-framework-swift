
import Foundation
import Criollo

class ControllerUtils {
    static func send<T>(res: CRResponse, data: T) where T: Encodable {
        res.setValue("application/json", forHTTPHeaderField: "Content-type")
        // swiftlint:disable:next force_try
        res.send(try! JSONEncoder().encode(data))
    }

    static func send(res: CRResponse, json: String) {
        res.setValue("application/json", forHTTPHeaderField: "Content-type")
        res.send(json)
    }

    static func sendEmptyResponse(res: CRResponse) {
        res.setValue("application/json", forHTTPHeaderField: "Content-type")
        res.send("{}")
    }
}
