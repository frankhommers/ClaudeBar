import Foundation
import Infrastructure
import Domain

/// Observable settings manager for ClaudeBar preferences.
/// Credentials are stored in UserDefaults via CredentialStore.
@MainActor
@Observable
public final class AppSettings {
    public static let shared = AppSettings()

    private let credentialStore: any CredentialStore

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
            credentialStore.save(githubUsername, forKey: CredentialKey.githubUsername)
        }
    }

    // MARK: - Token Management

    /// Whether a GitHub Copilot token is configured
    public var hasCopilotToken: Bool {
        credentialStore.exists(forKey: CredentialKey.githubToken)
    }

    /// Saves the GitHub Copilot token
    public func saveCopilotToken(_ token: String) {
        credentialStore.save(token, forKey: CredentialKey.githubToken)
    }

    /// Retrieves the GitHub Copilot token
    public func getCopilotToken() -> String? {
        credentialStore.get(forKey: CredentialKey.githubToken)
    }

    /// Deletes the GitHub Copilot token
    public func deleteCopilotToken() {
        credentialStore.delete(forKey: CredentialKey.githubToken)
    }

    // MARK: - Initialization

    private init(credentialStore: any CredentialStore = UserDefaultsCredentialStore.shared) {
        self.credentialStore = credentialStore
        self.copilotEnabled = UserDefaults.standard.bool(forKey: Keys.copilotEnabled)
        self.githubUsername = credentialStore.get(forKey: CredentialKey.githubUsername) ?? ""
    }
}

// MARK: - UserDefaults Keys

private extension AppSettings {
    enum Keys {
        static let copilotEnabled = "copilotEnabled"
    }
}
