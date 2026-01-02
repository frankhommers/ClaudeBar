package com.tddworks.claudebar.infrastructure.probes.gemini

import com.tddworks.claudebar.infrastructure.network.NetworkClient
import kotlinx.coroutines.delay
import kotlinx.serialization.json.Json

/**
 * Repository for discovering Gemini projects from Google Cloud.
 */
internal class GeminiProjectRepository(
    private val networkClient: NetworkClient,
    private val maxRetries: Int = 3,
    private val json: Json = Json { ignoreUnknownKeys = true }
) {
    companion object {
        private const val PROJECTS_ENDPOINT = "https://cloudresourcemanager.googleapis.com/v1/projects"
    }

    /**
     * Fetches the best Gemini project to use for quota checking.
     * Includes retry logic for cold-start network delays.
     */
    suspend fun fetchBestProject(accessToken: String): GeminiProject? {
        val projects = fetchProjects(accessToken) ?: return null
        return projects.bestProjectForQuota
    }

    /**
     * Fetches all available Gemini projects with retry logic.
     */
    suspend fun fetchProjects(accessToken: String): GeminiProjects? {
        val headers = mapOf(
            "Authorization" to "Bearer $accessToken"
        )

        var lastError: Throwable? = null

        for (attempt in 0 until maxRetries) {
            if (attempt > 0) {
                // Exponential backoff: 200ms, 500ms, 1000ms
                val delayMs = 200L * (attempt + 1)
                delay(delayMs)
            }

            try {
                val response = networkClient.get(PROJECTS_ENDPOINT, headers)

                when (response.statusCode) {
                    200 -> {
                        return try {
                            json.decodeFromString<GeminiProjects>(response.body)
                        } catch (e: Exception) {
                            null
                        }
                    }
                    401, 403 -> {
                        // Auth errors won't be fixed by retrying
                        return null
                    }
                }
            } catch (e: Exception) {
                lastError = e
            }
        }

        return null
    }
}
