package com.tddworks.claudebar.infrastructure.probes.gemini

import com.tddworks.claudebar.domain.model.ProbeError
import com.tddworks.claudebar.domain.model.QuotaType
import com.tddworks.claudebar.domain.model.UsageQuota
import com.tddworks.claudebar.domain.model.UsageSnapshot
import com.tddworks.claudebar.domain.provider.UsageProbe
import com.tddworks.claudebar.infrastructure.network.NetworkClient
import kotlinx.datetime.Clock
import kotlinx.serialization.Serializable
import kotlinx.serialization.json.Json
import kotlinx.serialization.json.JsonObject
import kotlinx.serialization.json.double
import kotlinx.serialization.json.jsonPrimitive

/**
 * Probe for fetching Gemini usage data via the Google Cloud Code API.
 *
 * Uses OAuth credentials stored by the Gemini CLI (~/.gemini/oauth_creds.json).
 */
class GeminiUsageProbe(
    private val networkClient: NetworkClient,
    private val credentialsProvider: GeminiCredentialsProvider,
    private val maxRetries: Int = 3,
    private val json: Json = Json { ignoreUnknownKeys = true }
) : UsageProbe {

    companion object {
        private const val QUOTA_ENDPOINT = "https://cloudcode-pa.googleapis.com/v1internal:retrieveUserQuota"
    }

    override suspend fun isAvailable(): Boolean {
        return credentialsProvider.hasCredentials()
    }

    override suspend fun probe(): UsageSnapshot {
        val credentials = credentialsProvider.loadCredentials()
            ?: throw ProbeError.AuthenticationRequired

        if (credentials.accessToken.isNullOrEmpty()) {
            throw ProbeError.AuthenticationRequired
        }

        // Discover project ID for accurate quota data
        val projectRepository = GeminiProjectRepository(networkClient, maxRetries, json)
        val projectId = projectRepository.fetchBestProject(credentials.accessToken)?.projectId

        val headers = mapOf(
            "Authorization" to "Bearer ${credentials.accessToken}",
            "Content-Type" to "application/json"
        )

        val body = if (projectId != null) {
            """{"project": "$projectId"}"""
        } else {
            "{}"
        }

        val response = networkClient.post(QUOTA_ENDPOINT, body, headers)

        when (response.statusCode) {
            200 -> {} // Continue
            401 -> throw ProbeError.AuthenticationRequired
            else -> throw ProbeError.ExecutionFailed("HTTP ${response.statusCode}")
        }

        return parseQuotaResponse(response.body)
    }

    private fun parseQuotaResponse(responseBody: String): UsageSnapshot {
        val response = try {
            json.decodeFromString<QuotaResponse>(responseBody)
        } catch (e: Exception) {
            throw ProbeError.ParseFailed("Failed to parse quota response: ${e.message}")
        }

        val buckets = response.buckets
        if (buckets.isNullOrEmpty()) {
            throw ProbeError.ParseFailed("No quota buckets in response")
        }

        // Group quotas by model, keeping lowest per model
        val modelQuotaMap = mutableMapOf<String, Pair<Double, String?>>()

        for (bucket in buckets) {
            val modelId = bucket.modelId ?: continue
            val fraction = bucket.remainingFraction ?: continue

            val existing = modelQuotaMap[modelId]
            if (existing == null || fraction < existing.first) {
                modelQuotaMap[modelId] = Pair(fraction, bucket.resetTime)
            }
        }

        val quotas = modelQuotaMap
            .entries
            .sortedBy { it.key }
            .map { (modelId, data) ->
                UsageQuota(
                    percentRemaining = data.first * 100,
                    quotaType = QuotaType.ModelSpecific(modelId),
                    providerId = "gemini",
                    resetText = data.second?.let { "Resets $it" }
                )
            }

        if (quotas.isEmpty()) {
            throw ProbeError.ParseFailed("No valid quotas found")
        }

        return UsageSnapshot(
            providerId = "gemini",
            quotas = quotas,
            capturedAt = Clock.System.now()
        )
    }
}

// MARK: - Response Models

@Serializable
internal data class QuotaResponse(
    val buckets: List<QuotaBucket>? = null
)

@Serializable
internal data class QuotaBucket(
    val remainingFraction: Double? = null,
    val resetTime: String? = null,
    val modelId: String? = null,
    val tokenType: String? = null
)

// MARK: - Credentials

data class GeminiCredentials(
    val accessToken: String?,
    val refreshToken: String?,
    val expiryDate: Long? = null
)

/**
 * Interface for loading Gemini OAuth credentials.
 * Platform-specific implementations handle file system access.
 */
interface GeminiCredentialsProvider {
    /**
     * Checks if credentials file exists.
     */
    suspend fun hasCredentials(): Boolean

    /**
     * Loads OAuth credentials from the Gemini CLI credentials file.
     */
    suspend fun loadCredentials(): GeminiCredentials?
}
