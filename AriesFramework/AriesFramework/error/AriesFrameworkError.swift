
import Foundation

public enum AriesFrameworkError: LocalizedError {
    case frameworkError(String, Error? = nil)
    case recordDuplicateError(String)
    case recordNotFoundError(String)

    public var errorDescription: String? {
        switch self {
        case .frameworkError(let message, let reason):
            if reason == nil {
                return "FrameworkError: \(message)"
            } else {
                return "FrameworkError: \(message), reason: \(failureReason!)"
            }
        case .recordDuplicateError(let message):
            return "RecordDuplicateError: " + message
        case .recordNotFoundError(let message):
            return "RecordNotFoundError: " + message
        }
    }
    
    public var failureReason: String? {
        switch self {
        case .frameworkError(_, let reason):
            if reason == nil {
                return nil
            } else {
                return reason?.localizedDescription
            }
        case .recordDuplicateError(_):
            return nil
        case .recordNotFoundError(_):
            return nil
        }
    }
}
