import Foundation
import Security

/// A service for securely storing and retrieving credentials in the macOS Keychain.
public final class KeychainService: @unchecked Sendable {
    public static let shared = KeychainService()

    private let service = "com.tddworks.claudebar"

    private init() {}

    // MARK: - Public API

    /// Saves a token to the Keychain.
    /// - Parameters:
    ///   - token: The token string to store
    ///   - account: The account identifier (e.g., "github-copilot-token")
    /// - Throws: KeychainError if the operation fails
    public func saveToken(_ token: String, for account: String) throws {
        guard let data = token.data(using: .utf8) else {
            throw KeychainError.encodingFailed
        }

        // Delete existing item first
        try? deleteToken(for: account)

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlocked
        ]

        let status = SecItemAdd(query as CFDictionary, nil)

        guard status == errSecSuccess else {
            throw KeychainError.saveFailed(status)
        }
    }

    /// Retrieves a token from the Keychain.
    /// - Parameter account: The account identifier
    /// - Returns: The stored token, or nil if not found
    public func getToken(for account: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        guard status == errSecSuccess,
              let data = result as? Data,
              let token = String(data: data, encoding: .utf8) else {
            return nil
        }

        return token
    }

    /// Deletes a token from the Keychain.
    /// - Parameter account: The account identifier
    /// - Throws: KeychainError if the operation fails
    public func deleteToken(for account: String) throws {
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

    /// Checks if a token exists for the given account.
    /// - Parameter account: The account identifier
    /// - Returns: true if a token exists
    public func hasToken(for account: String) -> Bool {
        getToken(for: account) != nil
    }
}

// MARK: - Account Keys

extension KeychainService {
    /// Well-known account keys for different providers
    public enum Account {
        public static let githubCopilotToken = "github-copilot-token"
    }
}

// MARK: - Errors

public enum KeychainError: LocalizedError {
    case encodingFailed
    case saveFailed(OSStatus)
    case deleteFailed(OSStatus)

    public var errorDescription: String? {
        switch self {
        case .encodingFailed:
            return "Failed to encode token data"
        case .saveFailed(let status):
            return "Failed to save to Keychain (status: \(status))"
        case .deleteFailed(let status):
            return "Failed to delete from Keychain (status: \(status))"
        }
    }
}