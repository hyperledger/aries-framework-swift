
import Foundation

public enum AriesFrameworkError: LocalizedError {
    case frameworkError(String)
    case recordDuplicateError(String)
    case recordNotFoundError(String)

    public var errorDescription: String? {
        switch self {
        case .frameworkError(let message):
            return "FrameworkError: " + message
        case .recordDuplicateError(let message):
            return "RecordDuplicateError: " + message
        case .recordNotFoundError(let message):
            return "RecordNotFoundError: " + message
        }
    }
}
