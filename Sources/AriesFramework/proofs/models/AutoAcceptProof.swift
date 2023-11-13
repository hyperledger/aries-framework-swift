
import Foundation

public enum AutoAcceptProof: String, Codable {
    /// Always auto accepts the proof no matter if it changed in subsequent steps
    case always

    /// Never auto accept a proof
    case never
}
