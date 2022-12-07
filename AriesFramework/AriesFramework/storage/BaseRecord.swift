
import Foundation

public protocol BaseRecord {
    var id: String { get set }
    static var type: String { get }
    var tags: Tags? { get set }
    func getTags() -> Tags
}

extension BaseRecord {
    public static func generateId() -> String {
        return UUID().uuidString
    }
}
