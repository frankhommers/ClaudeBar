package com.tddworks.claudebar.infrastructure.probes.claude

import com.tddworks.claudebar.domain.model.AccountTier
import com.tddworks.claudebar.domain.model.ProbeError
import com.tddworks.claudebar.domain.model.QuotaStatus
import com.tddworks.claudebar.infrastructure.cli.CLIExecutor
import com.tddworks.claudebar.infrastructure.cli.CLIResult
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertFailsWith
import kotlin.test.assertNotNull
import kotlin.test.assertNull
import kotlin.time.Duration

class ClaudeUsageProbeParsingTest {

    private val mockExecutor = object : CLIExecutor {
        override fun locate(binary: String): String? = "/usr/local/bin/claude"
        override suspend fun execute(
            binary: String,
            args: List<String>,
            input: String?,
            timeout: Duration,
            workingDirectory: String?,
            autoResponses: Map<String, String>
        ): CLIResult = CLIResult("", 0)
    }

    private val probe = ClaudeUsageProbe(mockExecutor)

    @Test
    fun `parses Claude Max output with session and weekly quotas`() {
        val output = """
            Opus 4.5 · Claude Max · user@example.com's Organization

            Current session
            █████████░ 90% left
            Resets in 2h 30m

            Current week (all models)
            ████████░░ 80% left
            Resets Jan 7
        """.trimIndent()

        val snapshot = probe.parseClaudeOutput(output)

        assertEquals("claude", snapshot.providerId)
        assertEquals(AccountTier.ClaudeMax, snapshot.accountTier)
        assertEquals(2, snapshot.quotas.size)
        assertEquals(90.0, snapshot.sessionQuota?.percentRemaining)
        assertEquals(80.0, snapshot.weeklyQuota?.percentRemaining)
    }

    @Test
    fun `parses Claude Pro output with extra usage`() {
        val output = """
            Opus 4.5 · Claude Pro · user@example.com

            Current session
            █████████░ 75% left
            Resets in 1h

            Extra usage
            █████ 27% used
            $5.41 / $20.00 spent · Resets Jan 1, 2026
        """.trimIndent()

        val snapshot = probe.parseClaudeOutput(output)

        assertEquals(AccountTier.ClaudePro, snapshot.accountTier)
        assertNotNull(snapshot.costUsage)
        assertEquals(5.41, snapshot.costUsage?.totalCost)
        assertEquals(20.0, snapshot.costUsage?.budget)
    }

    @Test
    fun `detects authentication required error`() {
        val output = "Error: token has expired. Please log in again."

        assertFailsWith<ProbeError.AuthenticationRequired> {
            probe.parseClaudeOutput(output)
        }
    }

    @Test
    fun `detects folder trust required error`() {
        val output = "Do you trust the files in this folder?\n/Users/test/project"

        assertFailsWith<ProbeError.FolderTrustRequired> {
            probe.parseClaudeOutput(output)
        }
    }

    @Test
    fun `detects update required error`() {
        val output = "Claude update required. Please update your CLI."

        assertFailsWith<ProbeError.UpdateRequired> {
            probe.parseClaudeOutput(output)
        }
    }

    @Test
    fun `strips ANSI codes correctly`() {
        val withAnsi = "\u001B[32mGreen text\u001B[0m and \u001B[1mBold\u001B[0m"
        val clean = probe.stripANSICodes(withAnsi)

        assertEquals("Green text and Bold", clean)
    }

    @Test
    fun `extracts percentage from used format`() {
        val pct = probe.percentFromLine("█████ 75% used")
        assertEquals(25, pct) // 100 - 75 = 25% remaining
    }

    @Test
    fun `extracts percentage from left format`() {
        val pct = probe.percentFromLine("█████████░ 90% left")
        assertEquals(90, pct)
    }

    @Test
    fun `parses extra usage cost line`() {
        val result = probe.parseExtraUsageCostLine("$5.41 / $20.00 spent")

        assertNotNull(result)
        assertEquals(5.41, result.first)
        assertEquals(20.0, result.second)
    }

    @Test
    fun `returns null for invalid cost line`() {
        val result = probe.parseExtraUsageCostLine("No cost info here")

        assertNull(result)
    }
}
