package com.tddworks.claudebar.infrastructure.probes.codex

import com.tddworks.claudebar.domain.model.ProbeError
import com.tddworks.claudebar.domain.model.QuotaType
import com.tddworks.claudebar.domain.model.UsageQuota
import com.tddworks.claudebar.domain.model.UsageSnapshot
import com.tddworks.claudebar.domain.provider.UsageProbe
import com.tddworks.claudebar.infrastructure.cli.CLIExecutor
import kotlinx.datetime.Clock
import kotlin.time.Duration
import kotlin.time.Duration.Companion.seconds

/**
 * Infrastructure adapter that probes the Codex CLI to fetch usage quotas.
 */
class CodexUsageProbe(
    private val cliExecutor: CLIExecutor,
    private val codexBinary: String = "codex",
    private val timeout: Duration = 20.seconds
) : UsageProbe {

    companion object {
        private val ANSI_PATTERN = Regex("""\x1B(?:[@-Z\\-_]|\[[0-?]*[ -/]*[@-~])""")
    }

    override suspend fun isAvailable(): Boolean {
        return cliExecutor.locate(codexBinary) != null
    }

    override suspend fun probe(): UsageSnapshot {
        val result = cliExecutor.execute(
            binary = codexBinary,
            args = listOf("/usage"),
            timeout = timeout
        )

        if (result.exitCode != 0 && result.output.isBlank()) {
            throw ProbeError.ExecutionFailed("Codex CLI failed with exit code ${result.exitCode}")
        }

        return parse(result.output)
    }

    internal fun parse(text: String): UsageSnapshot {
        val clean = stripANSICodes(text)

        extractUsageError(clean)?.let { throw it }

        val fiveHourPct = extractPercent("5h limit", clean)
        val weeklyPct = extractPercent("Weekly limit", clean)

        val quotas = mutableListOf<UsageQuota>()

        if (fiveHourPct != null) {
            quotas.add(
                UsageQuota(
                    percentRemaining = fiveHourPct.toDouble(),
                    quotaType = QuotaType.Session,
                    providerId = "codex"
                )
            )
        }

        if (weeklyPct != null) {
            quotas.add(
                UsageQuota(
                    percentRemaining = weeklyPct.toDouble(),
                    quotaType = QuotaType.Weekly,
                    providerId = "codex"
                )
            )
        }

        if (quotas.isEmpty()) {
            throw ProbeError.ParseFailed("Could not find usage limits in Codex output")
        }

        return UsageSnapshot(
            providerId = "codex",
            quotas = quotas,
            capturedAt = Clock.System.now()
        )
    }

    // MARK: - Text Parsing Helpers

    internal fun stripANSICodes(text: String): String {
        return text.replace(ANSI_PATTERN, "")
    }

    internal fun extractPercent(labelSubstring: String, text: String): Int? {
        val lines = text.lines()
        val label = labelSubstring.lowercase()

        for ((idx, line) in lines.withIndex()) {
            if (line.lowercase().contains(label)) {
                val window = lines.drop(idx).take(12)
                for (candidate in window) {
                    percentFromLine(candidate)?.let { return it }
                }
            }
        }
        return null
    }

    internal fun percentFromLine(line: String): Int? {
        val pattern = Regex("""([0-9]{1,3})%\s+left""", RegexOption.IGNORE_CASE)
        val match = pattern.find(line) ?: return null
        return match.groupValues[1].toIntOrNull()
    }

    internal fun extractUsageError(text: String): ProbeError? {
        val lower = text.lowercase()

        if (lower.contains("data not available yet")) {
            return ProbeError.ParseFailed("Data not available yet")
        }

        if (lower.contains("update available") && lower.contains("codex")) {
            return ProbeError.UpdateRequired
        }

        if (lower.contains("not logged in") || lower.contains("please log in")) {
            return ProbeError.AuthenticationRequired
        }

        return null
    }
}
