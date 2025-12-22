import Foundation
import Infrastructure

/// Observable settings manager for ClaudeBar preferences.
/// Tokens are stored securely in macOS Keychain.
@MainActor
@Observable
public final class AppSettings {
    public static let shared = AppSettings()

    // MARK: - Provider Settings

    /// Whether GitHub Copilot provider is enabled
    public var copilotEnabled: Bool {
        didSet {
            UserDefaults.standard.set(copilotEnabled, forKey: Keys.copilotEnabled)
        }
    }

    /// The GitHub username for Copilot API calls
    public var githubUsername: String {
        didSet {
            UserDefaults.standard.set(githubUsername, forKey: Keys.githubUsername)
        }
    }

    // MARK: - Token Management (Keychain)

    /// Whether a GitHub Copilot token is configured
    public var hasCopilotToken: Bool {
        KeychainService.shared.hasToken(for: KeychainService.Account.githubCopilotToken)
    }

    /// Saves the GitHub Copilot token to Keychain
    public func saveCopilotToken(_ token: String) throws {
        try KeychainService.shared.saveToken(token, for: KeychainService.Account.githubCopilotToken)
    }

    /// Retrieves the GitHub Copilot token from Keychain
    public func getCopilotToken() -> String? {
        KeychainService.shared.getToken(for: KeychainService.Account.githubCopilotToken)
    }

    /// Deletes the GitHub Copilot token from Keychain
    public func deleteCopilotToken() throws {
        try KeychainService.shared.deleteToken(for: KeychainService.Account.githubCopilotToken)
    }

    // MARK: - Initialization

    private init() {
        self.copilotEnabled = UserDefaults.standard.bool(forKey: Keys.copilotEnabled)
        self.githubUsername = UserDefaults.standard.string(forKey: Keys.githubUsername) ?? ""
    }
}

// MARK: - UserDefaults Keys

private extension AppSettings {
    enum Keys {
        static let copilotEnabled = "copilotEnabled"
        static let githubUsername = "githubUsername"
    }
}