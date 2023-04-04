import Foundation

enum ApplicationError: LocalizedError {
    case withMessage(String, Error? = nil)
    
    public var errorDescription: String? {
        switch self {
        case .withMessage(let message, let reason):
            if reason == nil {
                return message
            } else {
                return "\(message) reason: \(failureReason!)"
            }
        }
    }
    
    public var failureReason: String? {
        switch self {
        case .withMessage(_, let reason):
            if reason == nil {
                return nil
            } else {
                return reason?.localizedDescription
            }
        }
    }
}
