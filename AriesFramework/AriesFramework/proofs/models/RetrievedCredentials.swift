
import Foundation

public struct RetrievedCredentials {
    public var requestedAttributes: [String: [RequestedAttribute]]
    public var requestedPredicates: [String: [RequestedPredicate]]

    public init() {
        self.requestedAttributes = [:]
        self.requestedPredicates = [:]
    }
}
