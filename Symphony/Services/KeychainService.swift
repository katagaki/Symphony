import Foundation
import Security

nonisolated enum KeychainService {
    private static let serviceName = "com.tsubuzaki.Symphony"

    enum Key: String, CaseIterable {
        case issuerID = "issuer_id"
        case keyID = "key_id"
        case privateKey = "private_key"
    }

    nonisolated static func save(_ value: String, for key: Key) throws {
        guard let data = value.data(using: .utf8) else { return }

        // Delete existing item first
        delete(for: key)

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: key.rawValue,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        ]

        let status = SecItemAdd(query as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw KeychainError.saveFailed(status)
        }
    }

    nonisolated static func load(for key: Key) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: key.rawValue,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        guard status == errSecSuccess, let data = result as? Data else {
            return nil
        }

        return String(data: data, encoding: .utf8)
    }

    nonisolated static func delete(for key: Key) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: key.rawValue
        ]

        SecItemDelete(query as CFDictionary)
    }

    nonisolated static func hasCredentials() -> Bool {
        load(for: .issuerID) != nil
            && load(for: .keyID) != nil
            && load(for: .privateKey) != nil
    }

    nonisolated static func deleteAll() {
        for key in Key.allCases {
            delete(for: key)
        }
    }
}

nonisolated enum KeychainError: LocalizedError {
    case saveFailed(OSStatus)

    var errorDescription: String? {
        switch self {
        case .saveFailed(let status):
            return "Failed to save to Keychain (status: \(status))"
        }
    }
}
