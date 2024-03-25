
import Foundation
import PeerDID

public class PeerDIDService {
    let agent: Agent
    let logger = Logger(subsystem: "AriesFramework", category: "PeerDIDService")

    init(agent: Agent) {
        self.agent = agent
    }
}
