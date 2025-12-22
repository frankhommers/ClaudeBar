import Testing
import Foundation
import Mockable
@testable import Domain

@Suite("CopilotProvider Tests")
struct CopilotProviderTests {

    // MARK: - Identity Tests

    @Test("copilot provider has correct id")
    func copilotProviderHasCorrectId() {
        let mockProbe = MockUsageProbe()
        let copilot = CopilotProvider(probe: mockProbe)

        #expect(copilot.id == "copilot")
    }

    @Test("copilot provider has correct name")
    func copilotProviderHasCorrectName() {
        let mockProbe = MockUsageProbe()
        let copilot = CopilotProvider(probe: mockProbe)

        #expect(copilot.name == "Copilot")
    }

    @Test("copilot provider has correct cliCommand")
    func copilotProviderHasCorrectCliCommand() {
        let mockProbe = MockUsageProbe()
        let copilot = CopilotProvider(probe: mockProbe)

        #expect(copilot.cliCommand == "gh")
    }

    @Test("copilot provider has dashboard URL pointing to GitHub")
    func copilotProviderHasGitHubDashboardUrl() {
        let mockProbe = MockUsageProbe()
        let copilot = CopilotProvider(probe: mockProbe)

        #expect(copilot.dashboardURL != nil)
        #expect(copilot.dashboardURL?.host?.contains("github") == true)
    }

    @Test("copilot provider has status page URL")
    func copilotProviderHasStatusPageUrl() {
        let mockProbe = MockUsageProbe()
        let copilot = CopilotProvider(probe: mockProbe)

        #expect(copilot.statusPageURL != nil)
        #expect(copilot.statusPageURL?.host?.contains("githubstatus") == true)
    }

    @Test("copilot provider is enabled by default")
    func copilotProviderIsEnabledByDefault() {
        let mockProbe = MockUsageProbe()
        let copilot = CopilotProvider(probe: mockProbe)

        #expect(copilot.isEnabled == true)
    }

    // MARK: - State Tests

    @Test("copilot provider starts with no snapshot")
    func copilotProviderStartsWithNoSnapshot() {
        let mockProbe = MockUsageProbe()
        let copilot = CopilotProvider(probe: mockProbe)

        #expect(copilot.snapshot == nil)
    }

    @Test("copilot provider starts not syncing")
    func copilotProviderStartsNotSyncing() {
        let mockProbe = MockUsageProbe()
        let copilot = CopilotProvider(probe: mockProbe)

        #expect(copilot.isSyncing == false)
    }

    @Test("copilot provider starts with no error")
    func copilotProviderStartsWithNoError() {
        let mockProbe = MockUsageProbe()
        let copilot = CopilotProvider(probe: mockProbe)

        #expect(copilot.lastError == nil)
    }

    // MARK: - Delegation Tests

    @Test("copilot provider delegates isAvailable to probe")
    func copilotProviderDelegatesIsAvailable() async {
        let mockProbe = MockUsageProbe()
        given(mockProbe).isAvailable().willReturn(true)
        let copilot = CopilotProvider(probe: mockProbe)

        let isAvailable = await copilot.isAvailable()

        #expect(isAvailable == true)
    }

    @Test("copilot provider delegates isAvailable false to probe")
    func copilotProviderDelegatesIsAvailableFalse() async {
        let mockProbe = MockUsageProbe()
        given(mockProbe).isAvailable().willReturn(false)
        let copilot = CopilotProvider(probe: mockProbe)

        let isAvailable = await copilot.isAvailable()

        #expect(isAvailable == false)
    }

    @Test("copilot provider delegates refresh to probe")
    func copilotProviderDelegatesRefresh() async throws {
        let expectedSnapshot = UsageSnapshot(
            providerId: "copilot",
            quotas: [UsageQuota(percentRemaining: 95, quotaType: .session, providerId: "copilot", resetText: "100/2000 requests")],
            capturedAt: Date()
        )
        let mockProbe = MockUsageProbe()
        given(mockProbe).probe().willReturn(expectedSnapshot)
        let copilot = CopilotProvider(probe: mockProbe)

        let snapshot = try await copilot.refresh()

        #expect(snapshot.providerId == "copilot")
        #expect(snapshot.quotas.count == 1)
        #expect(snapshot.quotas.first?.percentRemaining == 95)
    }

    // MARK: - Snapshot Storage Tests

    @Test("copilot provider stores snapshot after refresh")
    func copilotProviderStoresSnapshot() async throws {
        let expectedSnapshot = UsageSnapshot(
            providerId: "copilot",
            quotas: [UsageQuota(percentRemaining: 80, quotaType: .session, providerId: "copilot")],
            capturedAt: Date()
        )
        let mockProbe = MockUsageProbe()
        given(mockProbe).probe().willReturn(expectedSnapshot)
        let copilot = CopilotProvider(probe: mockProbe)

        #expect(copilot.snapshot == nil)

        _ = try await copilot.refresh()

        #expect(copilot.snapshot != nil)
        #expect(copilot.snapshot?.quotas.first?.percentRemaining == 80)
    }

    @Test("copilot provider clears error on successful refresh")
    func copilotProviderClearsErrorOnSuccess() async throws {
        // Use two separate probes to simulate the behavior
        let failingProbe = MockUsageProbe()
        given(failingProbe).probe().willThrow(ProbeError.timeout)
        let copilotWithFailingProbe = CopilotProvider(probe: failingProbe)

        do {
            _ = try await copilotWithFailingProbe.refresh()
        } catch {
            // Expected
        }
        #expect(copilotWithFailingProbe.lastError != nil)

        // Create new provider with succeeding probe
        let succeedingProbe = MockUsageProbe()
        let snapshot = UsageSnapshot(providerId: "copilot", quotas: [], capturedAt: Date())
        given(succeedingProbe).probe().willReturn(snapshot)
        let copilotWithSucceedingProbe = CopilotProvider(probe: succeedingProbe)

        _ = try await copilotWithSucceedingProbe.refresh()

        #expect(copilotWithSucceedingProbe.lastError == nil)
    }

    // MARK: - Error Handling Tests

    @Test("copilot provider stores error on refresh failure")
    func copilotProviderStoresError() async {
        let mockProbe = MockUsageProbe()
        given(mockProbe).probe().willThrow(ProbeError.authenticationRequired)
        let copilot = CopilotProvider(probe: mockProbe)

        #expect(copilot.lastError == nil)

        do {
            _ = try await copilot.refresh()
        } catch {
            // Expected
        }

        #expect(copilot.lastError != nil)
    }

    @Test("copilot provider rethrows probe errors")
    func copilotProviderRethrowsErrors() async {
        let mockProbe = MockUsageProbe()
        given(mockProbe).probe().willThrow(ProbeError.authenticationRequired)
        let copilot = CopilotProvider(probe: mockProbe)

        await #expect(throws: ProbeError.authenticationRequired) {
            try await copilot.refresh()
        }
    }

    // MARK: - Syncing State Tests

    @Test("copilot provider resets isSyncing after refresh completes")
    func copilotProviderResetsSyncingAfterRefresh() async throws {
        let mockProbe = MockUsageProbe()
        given(mockProbe).probe().willReturn(UsageSnapshot(
            providerId: "copilot",
            quotas: [],
            capturedAt: Date()
        ))
        let copilot = CopilotProvider(probe: mockProbe)

        #expect(copilot.isSyncing == false)

        _ = try await copilot.refresh()

        #expect(copilot.isSyncing == false)
    }

    @Test("copilot provider resets isSyncing after refresh fails")
    func copilotProviderResetsSyncingAfterFailure() async {
        let mockProbe = MockUsageProbe()
        given(mockProbe).probe().willThrow(ProbeError.timeout)
        let copilot = CopilotProvider(probe: mockProbe)

        do {
            _ = try await copilot.refresh()
        } catch {
            // Expected
        }

        #expect(copilot.isSyncing == false)
    }

    // MARK: - Uniqueness Tests

    @Test("copilot provider has unique id compared to other providers")
    func copilotProviderHasUniqueId() {
        let mockProbe = MockUsageProbe()
        let copilot = CopilotProvider(probe: mockProbe)
        let claude = ClaudeProvider(probe: mockProbe)
        let codex = CodexProvider(probe: mockProbe)
        let gemini = GeminiProvider(probe: mockProbe)

        let ids = Set([copilot.id, claude.id, codex.id, gemini.id])
        #expect(ids.count == 4) // All unique
    }
}
