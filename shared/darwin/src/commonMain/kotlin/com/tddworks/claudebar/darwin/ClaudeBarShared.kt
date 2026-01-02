package com.tddworks.claudebar.darwin

import com.tddworks.claudebar.domain.monitor.QuotaAlerter
import com.tddworks.claudebar.domain.monitor.QuotaMonitor
import com.tddworks.claudebar.domain.provider.AIProvider
import com.tddworks.claudebar.domain.provider.AIProviderRepository
import com.tddworks.claudebar.domain.provider.CredentialRepository
import com.tddworks.claudebar.domain.provider.ProviderSettingsRepository
import com.tddworks.claudebar.infrastructure.cli.CLIExecutor
import com.tddworks.claudebar.infrastructure.cli.AppleCLIExecutor
import com.tddworks.claudebar.infrastructure.network.KtorNetworkClient
import com.tddworks.claudebar.infrastructure.network.createHttpClient
import com.tddworks.claudebar.infrastructure.probes.claude.ClaudeUsageProbe
import com.tddworks.claudebar.infrastructure.probes.codex.CodexUsageProbe
import com.tddworks.claudebar.infrastructure.probes.gemini.GeminiUsageProbe
import com.tddworks.claudebar.infrastructure.probes.gemini.DefaultGeminiCredentialsProvider
import com.tddworks.claudebar.infrastructure.probes.antigravity.AntigravityUsageProbe
import com.tddworks.claudebar.infrastructure.probes.zai.ZaiUsageProbe
import com.tddworks.claudebar.infrastructure.probes.copilot.CopilotUsageProbe
import com.tddworks.claudebar.domain.provider.ClaudeProvider
import com.tddworks.claudebar.domain.provider.CodexProvider
import com.tddworks.claudebar.domain.provider.GeminiProvider
import com.tddworks.claudebar.domain.provider.AntigravityProvider
import com.tddworks.claudebar.domain.provider.ZaiProvider
import com.tddworks.claudebar.domain.provider.CopilotProvider

/**
 * Entry point for the ClaudeBarShared framework.
 * Provides factory methods to create fully configured QuotaMonitor for Swift.
 */
object ClaudeBarShared {
    const val VERSION = "1.0.0"

    /**
     * Creates a fully configured QuotaMonitor with all providers.
     *
     * @param settingsRepository Storage for provider enabled states (UserDefaults)
     * @param credentialRepository Storage for credentials (Keychain)
     * @param cliExecutor Optional CLI executor (defaults to AppleCLIExecutor)
     * @param alerter Optional alerter for quota status changes
     */
    fun createQuotaMonitor(
        settingsRepository: ProviderSettingsRepository,
        credentialRepository: CredentialRepository,
        cliExecutor: CLIExecutor? = null,
        alerter: QuotaAlerter? = null
    ): QuotaMonitor {
        val executor = cliExecutor ?: AppleCLIExecutor()
        val httpClient = createHttpClient()
        val networkClient = KtorNetworkClient(httpClient)

        val providers = listOf<AIProvider>(
            ClaudeProvider(
                probe = ClaudeUsageProbe(executor),
                passProbe = null,  // ClaudePassProbe requires ClipboardReader
                settingsRepository = settingsRepository
            ),
            CodexProvider(
                probe = CodexUsageProbe(executor),
                settingsRepository = settingsRepository
            ),
            GeminiProvider(
                probe = GeminiUsageProbe(
                    networkClient = networkClient,
                    credentialsProvider = DefaultGeminiCredentialsProvider()
                ),
                settingsRepository = settingsRepository
            ),
            AntigravityProvider(
                probe = AntigravityUsageProbe(
                    cliExecutor = executor,
                    networkClient = networkClient
                ),
                settingsRepository = settingsRepository
            ),
            ZaiProvider(
                probe = ZaiUsageProbe(
                    cliExecutor = executor,
                    networkClient = networkClient
                ),
                settingsRepository = settingsRepository
            ),
            CopilotProvider(
                probe = CopilotUsageProbe(
                    networkClient = networkClient,
                    credentialRepository = credentialRepository
                ),
                settingsRepository = settingsRepository
            )
        )

        val repository = DefaultAIProviderRepository(providers)

        return QuotaMonitor(
            providers = repository,
            alerter = alerter
        )
    }
}

/**
 * Simple implementation of AIProviderRepository.
 */
private class DefaultAIProviderRepository(
    private val providerList: List<AIProvider>
) : AIProviderRepository {
    private val providers = providerList.toMutableList()

    override val all: List<AIProvider>
        get() = providers.toList()

    override val enabled: List<AIProvider>
        get() = providers.filter { it.isEnabled }

    override fun provider(id: String): AIProvider? =
        providers.find { it.id == id }

    override fun add(provider: AIProvider) {
        if (providers.none { it.id == provider.id }) {
            providers.add(provider)
        }
    }

    override fun remove(id: String) {
        providers.removeAll { it.id == id }
    }
}
