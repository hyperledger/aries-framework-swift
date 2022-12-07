
import Foundation

public class AsyncWaiter {
    let ONE_TICK = UInt64(1000000000.0 * 0.2)   // 0.2 seconds

    private var timeout: TimeInterval
    private var isDone: Bool

    public init(timeout: TimeInterval = 20) {
        self.timeout = timeout
        self.isDone = false
    }

    public func wait() async throws -> Bool {
        isDone = false
        let timeoutTimestamp = Date.timeIntervalSinceReferenceDate + timeout
        while !isDone {
            try await Task.sleep(nanoseconds: ONE_TICK)
            if Date.timeIntervalSinceReferenceDate > timeoutTimestamp {
                isDone = true
                return false
            }
        }

        return true
    }

    public func finish() {
        isDone = true
    }
}
