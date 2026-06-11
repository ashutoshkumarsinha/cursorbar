import Foundation
import Security

enum KeychainError: LocalizedError {
    case saveFailed(OSStatus)
    case readFailed(OSStatus)
    case deleteFailed(OSStatus)
    case dataConversionFailed

    var errorDescription: String? {
        switch self {
        case .saveFailed(let status):
            return "Failed to save token to Keychain (status \(status))."
        case .readFailed(let status):
            return "Failed to read token from Keychain (status \(status))."
        case .deleteFailed(let status):
            return "Failed to delete token from Keychain (status \(status))."
        case .dataConversionFailed:
            return "Failed to convert token data."
        }
    }
}

/// Stores the WorkosCursorSessionToken in the macOS Keychain (never plaintext on disk).
final class KeychainService {
    static let shared = KeychainService()

    private let service: String
    private let account: String

    init(
        service: String = "com.cursorbar.session",
        account: String = "WorkosCursorSessionToken"
    ) {
        self.service = service
        self.account = account
    }

    func saveSessionToken(_ token: String) throws {
        guard let data = token.data(using: .utf8) else {
            throw KeychainError.dataConversionFailed
        }

        try? deleteSessionToken()

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        ]

        let status = SecItemAdd(query as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw KeychainError.saveFailed(status)
        }
    }

    func readSessionToken() throws -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        if status == errSecItemNotFound { return nil }
        guard status == errSecSuccess else {
            throw KeychainError.readFailed(status)
        }
        guard let data = result as? Data,
              let token = String(data: data, encoding: .utf8) else {
            throw KeychainError.dataConversionFailed
        }
        return token
    }

    func deleteSessionToken() throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]

        let status = SecItemDelete(query as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw KeychainError.deleteFailed(status)
        }
    }

    var hasToken: Bool {
        guard let token = try? readSessionToken(), !token.isEmpty else {
            return false
        }
        return true
    }
}
