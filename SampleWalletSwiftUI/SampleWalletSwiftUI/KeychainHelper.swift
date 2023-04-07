// https://swiftsenpai.com/development/persist-data-using-keychain/
import OSLog
import Foundation

enum KeychainError : Error {
    case runtimeError(String)
}

final class KeychainHelper {
    
    static let standard = KeychainHelper()
    private let logger = Logger(subsystem: "KeychainHelper", category: "AliceWallet")
    private init() {}
    
    func save(_ value: String, service: String, account: String) throws
    {
        let data = value.data(using: .utf8)!
        let query = [
            kSecValueData: data,
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: account,
        ] as CFDictionary
        
        let status = SecItemAdd(query, nil)
        
        if status != errSecSuccess {
            throw KeychainError.runtimeError("save into keychain failed: \(status)")
        }
    }
    
    func read(service: String, account: String) -> String
    {
        let query = [
            kSecAttrService: service,
            kSecAttrAccount: account,
            kSecClass: kSecClassGenericPassword,
            kSecReturnData: true
        ] as CFDictionary
        
        var result: AnyObject?
        SecItemCopyMatching(query, &result)
        
        let data = result as? Data
        let str = String(decoding: data!, as: UTF8.self)
        logger.debug("keychain read=\(str)")
        return str
    }
    
    func delete(service: String, account: String)
    {
        let query = [
            kSecAttrService: service,
            kSecAttrAccount: account,
            kSecClass: kSecClassGenericPassword
        ] as CFDictionary
        
        SecItemDelete(query)
    }
}
