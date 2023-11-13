
import Foundation

public enum AutoAcceptCredential: String, Codable {
    /// Always auto accepts the credential no matter if it changed in subsequent steps
    case always

    /// Never auto accept a credential
    case never
}
