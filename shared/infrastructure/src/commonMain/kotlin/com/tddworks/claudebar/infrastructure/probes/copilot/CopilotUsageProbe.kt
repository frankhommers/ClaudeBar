package com.tddworks.claudebar.infrastructure.probes.copilot

import com.tddworks.claudebar.domain.model.ProbeError
import com.tddworks.claudebar.domain.model.QuotaType
import com.tddworks.claudebar.domain.model.UsageQuota
import com.tddworks.claudebar.domain.model.UsageSnapshot
import com.tddworks.claudebar.domain.provider.CredentialKey
import com.tddworks.claudebar.domain.provider.CredentialRepository
import com.tddworks.claudebar.domain.provider.UsageProbe
import com.tddworks.claudebar.infrastructure.network.NetworkClient
import com.tddworks.claudebar.infrastructure.network.NetworkResponse
import kotlinx.datetime.Clock
import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable
import kotlinx.serialization.json.Json

/**
 * Probe for fetching GitHub Copilot usage data via GitHub Billing API.
 *
 * Uses the GitHub REST API to fetch premium request usage:
 * `GET /users/{username}/settings/billing/premium_request/usage`
 *
 * Requires a fine-grained PAT with "Plan: read" permission.
 */
class CopilotUsageProbe(
    private val networkClient: NetworkClient,
    private val credentialRepository: CredentialRepository,
    private val json: Json = Json { ignoreUnknownKeys = true }
) : UsageProbe {

    companion object {
        private const val API_BASE_URL = "https://api.github.com"
        private const val API_VERSION = "2022-11-28"
        private const val MONTHLY_LIMIT = 2000.0
    }

    override suspend fun isAvailable(): Boolean {
        val token = credentialRepository.get(CredentialKey.GITHUB_TOKEN)
        val username = credentialRepository.get(CredentialKey.GITHUB_USERNAME)
        return !token.isNullOrEmpty() && !username.isNullOrEmpty()
    }

    override suspend fun probe(): UsageSnapshot {
        val token = credentialRepository.get(CredentialKey.GITHUB_TOKEN)
        if (token.isNullOrEmpty()) {
            throw ProbeError.AuthenticationRequired
        }

        val username = credentialRepository.get(CredentialKey.GITHUB_USERNAME)
        if (username.isNullOrEmpty()) {
            throw ProbeError.ExecutionFailed("GitHub username not configured")
        }

        val usageData = fetchBillingUsage(username, token)
        return parseUsageResponse(usageData, username)
    }

    private suspend fun fetchBillingUsage(username: String, token: String): PremiumRequestUsageResponse {
        val url = "$API_BASE_URL/users/$username/settings/billing/premium_request/usage"

        val headers = mapOf(
            "Authorization" to "Bearer $token",
            "Accept" to "application/vnd.github+json",
            "X-GitHub-Api-Version" to API_VERSION
        )

        val response: NetworkResponse = networkClient.get(url, headers)

        when (response.statusCode) {
            200 -> {} // Continue
            401 -> throw ProbeError.AuthenticationRequired
            403 -> throw ProbeError.ExecutionFailed("Forbidden - ensure PAT has 'Plan: read' permission")
            404 -> throw ProbeError.ExecutionFailed("User not found or no billing access")
            else -> throw ProbeError.ExecutionFailed("HTTP error: ${response.statusCode}")
        }

        return try {
            json.decodeFromString<PremiumRequestUsageResponse>(response.body)
        } catch (e: Exception) {
            throw ProbeError.ParseFailed("Failed to parse billing response: ${e.message}")
        }
    }

    private fun parseUsageResponse(response: PremiumRequestUsageResponse, username: String): UsageSnapshot {
        val copilotItems = response.usageItems.filter { item ->
            item.product?.lowercase()?.contains("copilot") == true
        }

        val totalGrossQuantity = copilotItems.sumOf { it.grossQuantity ?: 0.0 }
        val used = totalGrossQuantity
        val remaining = maxOf(0.0, MONTHLY_LIMIT - used)
        val percentRemaining = (remaining / MONTHLY_LIMIT) * 100

        val quota = UsageQuota(
            percentRemaining = percentRemaining,
            quotaType = QuotaType.Session,
            providerId = "copilot",
            resetText = "${used.toInt()}/${MONTHLY_LIMIT.toInt()} requests"
        )

        return UsageSnapshot(
            providerId = "copilot",
            quotas = listOf(quota),
            capturedAt = Clock.System.now(),
            accountEmail = username
        )
    }
}

// MARK: - API Response Models

@Serializable
internal data class PremiumRequestUsageResponse(
    @SerialName("time_period") val timePeriod: TimePeriod,
    val user: String,
    @SerialName("usage_items") val usageItems: List<PremiumUsageItem>
) {
    @Serializable
    data class TimePeriod(
        val year: Int,
        val month: Int
    )
}

@Serializable
internal data class PremiumUsageItem(
    val product: String? = null,
    val sku: String? = null,
    val model: String? = null,
    @SerialName("unit_type") val unitType: String? = null,
    @SerialName("price_per_unit") val pricePerUnit: Double? = null,
    @SerialName("gross_quantity") val grossQuantity: Double? = null,
    @SerialName("gross_amount") val grossAmount: Double? = null,
    @SerialName("discount_quantity") val discountQuantity: Double? = null,
    @SerialName("discount_amount") val discountAmount: Double? = null,
    @SerialName("net_quantity") val netQuantity: Double? = null,
    @SerialName("net_amount") val netAmount: Double? = null
)
