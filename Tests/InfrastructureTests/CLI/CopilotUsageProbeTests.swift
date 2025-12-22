import Testing
import Foundation
import Mockable
@testable import Infrastructure
@testable import Domain

@Suite("CopilotUsageProbe Tests")
struct CopilotUsageProbeTests {

    // MARK: - isAvailable Tests

    @Test("isAvailable returns true when token and username are configured")
    func isAvailableReturnsTrueWhenConfigured() async {
        // Given
        let mockStore = MockCredentialStore()
        given(mockStore).get(forKey: .value(CredentialKey.githubToken)).willReturn("ghp_test_token")
        given(mockStore).get(forKey: .value(CredentialKey.githubUsername)).willReturn("testuser")

        let probe = CopilotUsageProbe(credentialStore: mockStore)

        // When & Then
        #expect(await probe.isAvailable() == true)
    }

    @Test("isAvailable returns false when token is missing")
    func isAvailableReturnsFalseWhenTokenMissing() async {
        // Given
        let mockStore = MockCredentialStore()
        given(mockStore).get(forKey: .value(CredentialKey.githubToken)).willReturn(nil)
        given(mockStore).get(forKey: .value(CredentialKey.githubUsername)).willReturn("testuser")

        let probe = CopilotUsageProbe(credentialStore: mockStore)

        // When & Then
        #expect(await probe.isAvailable() == false)
    }

    @Test("isAvailable returns false when username is missing")
    func isAvailableReturnsFalseWhenUsernameMissing() async {
        // Given
        let mockStore = MockCredentialStore()
        given(mockStore).get(forKey: .value(CredentialKey.githubToken)).willReturn("ghp_test_token")
        given(mockStore).get(forKey: .value(CredentialKey.githubUsername)).willReturn(nil)

        let probe = CopilotUsageProbe(credentialStore: mockStore)

        // When & Then
        #expect(await probe.isAvailable() == false)
    }

    @Test("isAvailable returns false when token is empty")
    func isAvailableReturnsFalseWhenTokenEmpty() async {
        // Given
        let mockStore = MockCredentialStore()
        given(mockStore).get(forKey: .value(CredentialKey.githubToken)).willReturn("")
        given(mockStore).get(forKey: .value(CredentialKey.githubUsername)).willReturn("testuser")

        let probe = CopilotUsageProbe(credentialStore: mockStore)

        // When & Then
        #expect(await probe.isAvailable() == false)
    }

    // MARK: - Probe Tests

    @Test("probe throws authenticationRequired when token is missing")
    func probeThrowsWhenTokenMissing() async throws {
        // Given
        let mockStore = MockCredentialStore()
        given(mockStore).get(forKey: .value(CredentialKey.githubToken)).willReturn(nil)
        given(mockStore).get(forKey: .value(CredentialKey.githubUsername)).willReturn("testuser")

        let probe = CopilotUsageProbe(credentialStore: mockStore)

        // When & Then
        await #expect(throws: ProbeError.authenticationRequired) {
            try await probe.probe()
        }
    }

    @Test("probe throws executionFailed when username is missing")
    func probeThrowsWhenUsernameMissing() async throws {
        // Given
        let mockStore = MockCredentialStore()
        given(mockStore).get(forKey: .value(CredentialKey.githubToken)).willReturn("ghp_token")
        given(mockStore).get(forKey: .value(CredentialKey.githubUsername)).willReturn(nil)

        let probe = CopilotUsageProbe(credentialStore: mockStore)

        // When & Then
        await #expect(throws: ProbeError.self) {
            try await probe.probe()
        }
    }

    @Test("probe parses valid response correctly")
    func probeParseValidResponse() async throws {
        // Given
        let mockStore = MockCredentialStore()
        given(mockStore).get(forKey: .value(CredentialKey.githubToken)).willReturn("ghp_token")
        given(mockStore).get(forKey: .value(CredentialKey.githubUsername)).willReturn("testuser")

        let mockNetwork = MockNetworkClient()
        let responseJSON = """
        {
          "timePeriod": { "year": 2025, "month": 12 },
          "user": "testuser",
          "usageItems": [
            {
              "product": "Copilot",
              "sku": "Copilot Premium Request",
              "model": "Claude Sonnet 4",
              "unitType": "requests",
              "pricePerUnit": 0.04,
              "grossQuantity": 100.0,
              "grossAmount": 4.0,
              "discountQuantity": 100.0,
              "discountAmount": 4.0,
              "netQuantity": 0.0,
              "netAmount": 0.0
            }
          ]
        }
        """.data(using: .utf8)!

        let response = HTTPURLResponse(
            url: URL(string: "https://api.github.com")!,
            statusCode: 200,
            httpVersion: nil,
            headerFields: nil
        )!

        given(mockNetwork).request(.any).willReturn((responseJSON, response))

        let probe = CopilotUsageProbe(
            networkClient: mockNetwork,
            credentialStore: mockStore
        )

        // When
        let snapshot = try await probe.probe()

        // Then
        #expect(snapshot.providerId == "copilot")
        #expect(snapshot.accountEmail == "testuser")
        #expect(snapshot.quotas.count == 1)

        let quota = snapshot.quotas.first!
        #expect(quota.quotaType == .session)
        // 100 used out of 2000 = 95% remaining
        #expect(quota.percentRemaining == 95.0)
        #expect(quota.resetText == "100/2000 requests")
    }

    @Test("probe calculates percentage correctly with multiple items")
    func probeCalculatesMultipleItems() async throws {
        // Given
        let mockStore = MockCredentialStore()
        given(mockStore).get(forKey: .value(CredentialKey.githubToken)).willReturn("ghp_token")
        given(mockStore).get(forKey: .value(CredentialKey.githubUsername)).willReturn("testuser")

        let mockNetwork = MockNetworkClient()
        let responseJSON = """
        {
          "timePeriod": { "year": 2025, "month": 12 },
          "user": "testuser",
          "usageItems": [
            {
              "product": "Copilot",
              "sku": "Copilot Premium Request",
              "model": "Claude Sonnet 4",
              "grossQuantity": 50.0
            },
            {
              "product": "Copilot",
              "sku": "Copilot Premium Request",
              "model": "GPT-4o",
              "grossQuantity": 150.0
            },
            {
              "product": "Actions",
              "sku": "Actions Linux",
              "grossQuantity": 1000.0
            }
          ]
        }
        """.data(using: .utf8)!

        let response = HTTPURLResponse(
            url: URL(string: "https://api.github.com")!,
            statusCode: 200,
            httpVersion: nil,
            headerFields: nil
        )!

        given(mockNetwork).request(.any).willReturn((responseJSON, response))

        let probe = CopilotUsageProbe(
            networkClient: mockNetwork,
            credentialStore: mockStore
        )

        // When
        let snapshot = try await probe.probe()

        // Then
        let quota = snapshot.quotas.first!
        // 50 + 150 = 200 used (Actions excluded), 2000 - 200 = 1800 remaining = 90%
        #expect(quota.percentRemaining == 90.0)
        #expect(quota.resetText == "200/2000 requests")
    }

    @Test("probe returns 100% remaining when no usage")
    func probeReturns100WhenNoUsage() async throws {
        // Given
        let mockStore = MockCredentialStore()
        given(mockStore).get(forKey: .value(CredentialKey.githubToken)).willReturn("ghp_token")
        given(mockStore).get(forKey: .value(CredentialKey.githubUsername)).willReturn("testuser")

        let mockNetwork = MockNetworkClient()
        let responseJSON = """
        {
          "timePeriod": { "year": 2025, "month": 12 },
          "user": "testuser",
          "usageItems": []
        }
        """.data(using: .utf8)!

        let response = HTTPURLResponse(
            url: URL(string: "https://api.github.com")!,
            statusCode: 200,
            httpVersion: nil,
            headerFields: nil
        )!

        given(mockNetwork).request(.any).willReturn((responseJSON, response))

        let probe = CopilotUsageProbe(
            networkClient: mockNetwork,
            credentialStore: mockStore
        )

        // When
        let snapshot = try await probe.probe()

        // Then
        let quota = snapshot.quotas.first!
        #expect(quota.percentRemaining == 100.0)
        #expect(quota.resetText == "0/2000 requests")
    }

    // MARK: - Error Handling Tests

    @Test("probe throws authenticationRequired on 401 response")
    func probeThrowsOn401() async throws {
        // Given
        let mockStore = MockCredentialStore()
        given(mockStore).get(forKey: .value(CredentialKey.githubToken)).willReturn("ghp_token")
        given(mockStore).get(forKey: .value(CredentialKey.githubUsername)).willReturn("testuser")

        let mockNetwork = MockNetworkClient()
        let response = HTTPURLResponse(
            url: URL(string: "https://api.github.com")!,
            statusCode: 401,
            httpVersion: nil,
            headerFields: nil
        )!

        given(mockNetwork).request(.any).willReturn((Data(), response))

        let probe = CopilotUsageProbe(
            networkClient: mockNetwork,
            credentialStore: mockStore
        )

        // When & Then
        await #expect(throws: ProbeError.authenticationRequired) {
            try await probe.probe()
        }
    }

    @Test("probe throws executionFailed on 403 response")
    func probeThrowsOn403() async throws {
        // Given
        let mockStore = MockCredentialStore()
        given(mockStore).get(forKey: .value(CredentialKey.githubToken)).willReturn("ghp_token")
        given(mockStore).get(forKey: .value(CredentialKey.githubUsername)).willReturn("testuser")

        let mockNetwork = MockNetworkClient()
        let response = HTTPURLResponse(
            url: URL(string: "https://api.github.com")!,
            statusCode: 403,
            httpVersion: nil,
            headerFields: nil
        )!

        given(mockNetwork).request(.any).willReturn((Data(), response))

        let probe = CopilotUsageProbe(
            networkClient: mockNetwork,
            credentialStore: mockStore
        )

        // When & Then
        await #expect(throws: ProbeError.self) {
            try await probe.probe()
        }
    }

    @Test("probe throws parseFailed on invalid JSON")
    func probeThrowsOnInvalidJSON() async throws {
        // Given
        let mockStore = MockCredentialStore()
        given(mockStore).get(forKey: .value(CredentialKey.githubToken)).willReturn("ghp_token")
        given(mockStore).get(forKey: .value(CredentialKey.githubUsername)).willReturn("testuser")

        let mockNetwork = MockNetworkClient()
        let invalidJSON = "not valid json".data(using: .utf8)!
        let response = HTTPURLResponse(
            url: URL(string: "https://api.github.com")!,
            statusCode: 200,
            httpVersion: nil,
            headerFields: nil
        )!

        given(mockNetwork).request(.any).willReturn((invalidJSON, response))

        let probe = CopilotUsageProbe(
            networkClient: mockNetwork,
            credentialStore: mockStore
        )

        // When & Then
        await #expect(throws: ProbeError.self) {
            try await probe.probe()
        }
    }
}
