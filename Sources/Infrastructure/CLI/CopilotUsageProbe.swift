import Foundation
import Domain
import Mockable
import os.log

private let logger = Logger(subsystem: "com.claudebar", category: "CopilotUsageProbe")

/// Protocol for providing GitHub credentials
@Mockable
public protocol GitHubCredentialProvider: Sendable {
    func getToken() -> String?
    func getUsername() -> String?
}

/// Default credential provider that uses KeychainService
public struct KeychainCredentialProvider: GitHubCredentialProvider {
    public init() {}

    public func getToken() -> String? {
        KeychainService.shared.getToken(for: KeychainService.Account.githubCopilotToken)
    }

    public func getUsername() -> String? {
        UserDefaults.standard.string(forKey: "githubUsername")
    }
}

/// Probe for fetching GitHub Copilot usage data via GitHub Billing API.
///
/// Uses the GitHub REST API to fetch premium request usage:
/// `GET /users/{username}/settings/billing/usage`
///
/// Requires a fine-grained PAT with "Plan: read" permission.
public struct CopilotUsageProbe: UsageProbe {
    private let networkClient: any NetworkClient
    private let credentialProvider: any GitHubCredentialProvider
    private let timeout: TimeInterval

    private static let apiBaseURL = "https://api.github.com"
    private static let apiVersion = "2022-11-28"

    public init(
        networkClient: any NetworkClient = URLSession.shared,
        credentialProvider: any GitHubCredentialProvider = KeychainCredentialProvider(),
        timeout: TimeInterval = 30
    ) {
        self.networkClient = networkClient
        self.credentialProvider = credentialProvider
        self.timeout = timeout
    }

    public func isAvailable() async -> Bool {
        guard let token = credentialProvider.getToken(),
              let username = credentialProvider.getUsername(),
              !token.isEmpty,
              !username.isEmpty else {
            logger.debug("Copilot: Not available - missing token or username")
            return false
        }
        return true
    }

    public func probe() async throws -> UsageSnapshot {
        guard let token = credentialProvider.getToken(), !token.isEmpty else {
            logger.error("Copilot: No GitHub token configured")
            throw ProbeError.authenticationRequired
        }

        guard let username = credentialProvider.getUsername(), !username.isEmpty else {
            logger.error("Copilot: No GitHub username configured")
            throw ProbeError.executionFailed("GitHub username not configured")
        }

        logger.debug("Copilot: Fetching billing usage for \(username)")

        // Fetch billing usage
        let usageData = try await fetchBillingUsage(username: username, token: token)

        // Parse and create snapshot
        return try parseUsageResponse(usageData, username: username)
    }

    // MARK: - API Calls

    private func fetchBillingUsage(username: String, token: String) async throws -> BillingUsageResponse {
        // Get current month's usage
        let now = Date()
        let calendar = Calendar.current
        let year = calendar.component(.year, from: now)
        let month = calendar.component(.month, from: now)

        let urlString = "\(Self.apiBaseURL)/users/\(username)/settings/billing/usage?year=\(year)&month=\(month)"

        guard let url = URL(string: urlString) else {
            throw ProbeError.executionFailed("Invalid URL")
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        request.setValue(Self.apiVersion, forHTTPHeaderField: "X-GitHub-Api-Version")
        request.timeoutInterval = timeout

        let (data, response) = try await networkClient.request(request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw ProbeError.executionFailed("Invalid response")
        }

        logger.debug("Copilot API response status: \(httpResponse.statusCode)")

        switch httpResponse.statusCode {
        case 200:
            break
        case 401:
            logger.error("Copilot: Authentication failed (401)")
            throw ProbeError.authenticationRequired
        case 403:
            logger.error("Copilot: Forbidden - check token permissions (403)")
            throw ProbeError.executionFailed("Forbidden - ensure PAT has 'Plan: read' permission")
        case 404:
            logger.error("Copilot: User not found or no billing access (404)")
            throw ProbeError.executionFailed("User not found or no billing access")
        default:
            logger.error("Copilot: HTTP error \(httpResponse.statusCode)")
            throw ProbeError.executionFailed("HTTP error: \(httpResponse.statusCode)")
        }

        do {
            return try JSONDecoder().decode(BillingUsageResponse.self, from: data)
        } catch {
            logger.error("Copilot: Failed to parse response - \(error.localizedDescription)")
            // Log raw response for debugging
            if let rawString = String(data: data, encoding: .utf8) {
                logger.debug("Raw response: \(rawString.prefix(500))")
            }
            throw ProbeError.parseFailed("Failed to parse billing response: \(error.localizedDescription)")
        }
    }

    // MARK: - Response Parsing

    private func parseUsageResponse(_ response: BillingUsageResponse, username: String) throws -> UsageSnapshot {
        // Filter for Copilot usage items
        let copilotItems = response.usageItems.filter { item in
            item.product?.lowercased().contains("copilot") == true
        }

        logger.debug("Copilot: Found \(copilotItems.count) Copilot usage items")

        // Calculate totals
        var totalQuantity: Double = 0
        var totalNetAmount: Double = 0
        var totalDiscountAmount: Double = 0

        for item in copilotItems {
            totalQuantity += item.quantity ?? 0
            totalNetAmount += item.netAmount ?? 0
            totalDiscountAmount += item.discountAmount ?? 0
        }

        // Calculate included units from discount
        // Assumes a price per unit to derive included quota
        let pricePerUnit: Double = 0.04 // Premium request price (approximate)
        let includedUnits = totalDiscountAmount > 0 ? totalDiscountAmount / pricePerUnit : 2500 // Default free tier

        // Calculate percentage remaining
        let totalAllowed = includedUnits
        let used = totalQuantity
        let remaining = max(0, totalAllowed - used)
        let percentRemaining = totalAllowed > 0 ? (remaining / totalAllowed) * 100 : 100

        logger.debug("Copilot: Used \(Int(used))/\(Int(totalAllowed)) requests, \(Int(percentRemaining))% remaining")

        // Create quota
        let quota = UsageQuota(
            percentRemaining: percentRemaining,
            quotaType: .session,
            providerId: "copilot",
            resetText: "Resets monthly"
        )

        return UsageSnapshot(
            providerId: "copilot",
            quotas: [quota],
            capturedAt: Date(),
            accountEmail: username
        )
    }
}

// MARK: - API Response Models

private struct BillingUsageResponse: Decodable {
    let usageItems: [UsageItem]

    enum CodingKeys: String, CodingKey {
        case usageItems = "usage_items"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.usageItems = (try? container.decode([UsageItem].self, forKey: .usageItems)) ?? []
    }
}

private struct UsageItem: Decodable {
    let date: String?
    let product: String?
    let sku: String?
    let quantity: Double?
    let unitType: String?
    let pricePerUnit: Double?
    let grossAmount: Double?
    let discountAmount: Double?
    let netAmount: Double?

    enum CodingKeys: String, CodingKey {
        case date, product, sku, quantity
        case unitType = "unit_type"
        case pricePerUnit = "price_per_unit"
        case grossAmount = "gross_amount"
        case discountAmount = "discount_amount"
        case netAmount = "net_amount"
    }
}
