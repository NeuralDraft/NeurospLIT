import Foundation
import Security

// MARK: - Keychain Service for Secure Storage
final class KeychainService {
    static let shared = KeychainService()
    private init() {}
    
    private let serviceName = "NeurospLIT"
    
    enum KeychainError: LocalizedError {
        case duplicateEntry
        case itemNotFound
        case unexpectedData
        case unexpectedError(OSStatus)
        
        var errorDescription: String? {
            switch self {
            case .duplicateEntry:
                return "Item already exists in keychain"
            case .itemNotFound:
                return "Item not found in keychain"
            case .unexpectedData:
                return "Unexpected data format in keychain"
            case .unexpectedError(let status):
                return "Keychain error: \(status)"
            }
        }
    }
    
    // MARK: - Save
    func save(key: String, value: String) throws {
        guard let data = value.data(using: .utf8) else {
            throw KeychainError.unexpectedData
        }
        
        // Try to update first
        let updateQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecAttrService as String: serviceName
        ]
        
        let updateAttributes: [String: Any] = [
            kSecValueData as String: data
        ]
        
        var status = SecItemUpdate(updateQuery as CFDictionary, updateAttributes as CFDictionary)
        
        // If item doesn't exist, add it
        if status == errSecItemNotFound {
            let addQuery: [String: Any] = [
                kSecClass as String: kSecClassGenericPassword,
                kSecAttrAccount as String: key,
                kSecAttrService as String: serviceName,
                kSecValueData as String: data,
                kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly
            ]
            
            status = SecItemAdd(addQuery as CFDictionary, nil)
        }
        
        guard status == errSecSuccess else {
            throw KeychainError.unexpectedError(status)
        }
    }
    
    // MARK: - Retrieve
    func retrieve(key: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecAttrService as String: serviceName,
            kSecMatchLimit as String: kSecMatchLimitOne,
            kSecReturnData as String: true
        ]
        
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        
        guard status == errSecSuccess,
              let data = result as? Data,
              let value = String(data: data, encoding: .utf8) else {
            return nil
        }
        
        return value
    }
    
    // MARK: - Delete
    func delete(key: String) throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecAttrService as String: serviceName
        ]
        
        let status = SecItemDelete(query as CFDictionary)
        
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw KeychainError.unexpectedError(status)
        }
    }
    
    // MARK: - Check if exists
    func exists(key: String) -> Bool {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecAttrService as String: serviceName,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        
        return status == errSecSuccess
    }
    
    // MARK: - Clear all
    func clearAll() throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName
        ]
        
        let status = SecItemDelete(query as CFDictionary)
        
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw KeychainError.unexpectedError(status)
        }
    }
}

// MARK: - API Key Management Extension
extension KeychainService {
    private static let apiKeyIdentifier = "DEEPSEEK_API_KEY"
    
    func saveAPIKey(_ apiKey: String) throws {
        try save(key: Self.apiKeyIdentifier, value: apiKey)
        AppLogger.info("API key saved to keychain")
    }
    
    func retrieveAPIKey() -> String? {
        if let key = retrieve(key: Self.apiKeyIdentifier) {
            AppLogger.debug("API key retrieved from keychain")
            return key
        }
        
        // Fallback to Info.plist for development
        #if DEBUG
        if let bundleKey = Bundle.main.infoDictionary?["DEEPSEEK_API_KEY"] as? String,
           !bundleKey.isEmpty && bundleKey != "SET-YOUR-DEEPSEEK-API-KEY" {
            AppLogger.debug("API key retrieved from Info.plist (DEBUG mode)")
            return bundleKey
        }
        #endif
        
        AppLogger.warning("No API key found in keychain or Info.plist")
        return nil
    }
    
    func deleteAPIKey() throws {
        try delete(key: Self.apiKeyIdentifier)
        AppLogger.info("API key removed from keychain")
    }
    
    func hasAPIKey() -> Bool {
        return exists(key: Self.apiKeyIdentifier) || retrieveAPIKey() != nil
    }
}
