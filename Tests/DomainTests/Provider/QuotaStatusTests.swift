import Testing
import Foundation
@testable import Domain

@Suite
struct QuotaStatusTests {

    // MARK: - Factory Method Tests

    @Test
    func `healthy status for percentage above 50`() {
        #expect(QuotaStatus.from(percentRemaining: 100) == .healthy)
        #expect(QuotaStatus.from(percentRemaining: 75) == .healthy)
        #expect(QuotaStatus.from(percentRemaining: 51) == .healthy)
        #expect(QuotaStatus.from(percentRemaining: 50) == .healthy)
    }

    @Test
    func `warning status for percentage between 20 and 50`() {
        #expect(QuotaStatus.from(percentRemaining: 49) == .warning)
        #expect(QuotaStatus.from(percentRemaining: 35) == .warning)
        #expect(QuotaStatus.from(percentRemaining: 20) == .warning)
    }

    @Test
    func `critical status for percentage between 0 and 20`() {
        #expect(QuotaStatus.from(percentRemaining: 19) == .critical)
        #expect(QuotaStatus.from(percentRemaining: 10) == .critical)
        #expect(QuotaStatus.from(percentRemaining: 1) == .critical)
    }

    @Test
    func `depleted status for zero or negative percentage`() {
        #expect(QuotaStatus.from(percentRemaining: 0) == .depleted)
        #expect(QuotaStatus.from(percentRemaining: -1) == .depleted)
        #expect(QuotaStatus.from(percentRemaining: -100) == .depleted)
    }

    // MARK: - Needs Attention Tests

    @Test
    func `healthy status does not need attention`() {
        #expect(QuotaStatus.healthy.needsAttention == false)
    }

    @Test
    func `warning status needs attention`() {
        #expect(QuotaStatus.warning.needsAttention == true)
    }

    @Test
    func `critical status needs attention`() {
        #expect(QuotaStatus.critical.needsAttention == true)
    }

    @Test
    func `depleted status needs attention`() {
        #expect(QuotaStatus.depleted.needsAttention == true)
    }

    // MARK: - Comparison Tests (Severity Order)

    @Test
    func `healthy is less severe than warning`() {
        #expect(QuotaStatus.healthy < QuotaStatus.warning)
    }

    @Test
    func `warning is less severe than critical`() {
        #expect(QuotaStatus.warning < QuotaStatus.critical)
    }

    @Test
    func `critical is less severe than depleted`() {
        #expect(QuotaStatus.critical < QuotaStatus.depleted)
    }

    @Test
    func `depleted is most severe`() {
        #expect(QuotaStatus.depleted > QuotaStatus.healthy)
        #expect(QuotaStatus.depleted > QuotaStatus.warning)
        #expect(QuotaStatus.depleted > QuotaStatus.critical)
    }

    @Test
    func `max of multiple statuses returns worst status`() {
        let statuses: [QuotaStatus] = [.healthy, .warning, .critical]
        #expect(statuses.max() == .critical)

        let mixedStatuses: [QuotaStatus] = [.warning, .depleted, .healthy]
        #expect(mixedStatuses.max() == .depleted)
    }

    // MARK: - Equality Tests

    @Test
    func `status equals itself`() {
        #expect(QuotaStatus.healthy == .healthy)
        #expect(QuotaStatus.warning == .warning)
        #expect(QuotaStatus.critical == .critical)
        #expect(QuotaStatus.depleted == .depleted)
    }

    @Test
    func `different statuses are not equal`() {
        #expect(QuotaStatus.healthy != .warning)
        #expect(QuotaStatus.warning != .critical)
        #expect(QuotaStatus.critical != .depleted)
    }

    // MARK: - Hashable Tests

    @Test
    func `status can be used as dictionary key`() {
        var dict: [QuotaStatus: String] = [:]
        dict[.healthy] = "green"
        dict[.warning] = "yellow"

        #expect(dict[.healthy] == "green")
        #expect(dict[.warning] == "yellow")
    }

    @Test
    func `status can be used in set`() {
        let statuses: Set<QuotaStatus> = [.healthy, .warning, .healthy]
        #expect(statuses.count == 2)
    }
}
