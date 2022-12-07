
import Foundation

protocol PublicKey {
    var id: String { get }
    var controller: String { get }
    var type: String { get }
    var value: String? { get }
}
