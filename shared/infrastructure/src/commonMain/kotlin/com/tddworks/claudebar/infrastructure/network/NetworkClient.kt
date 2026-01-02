package com.tddworks.claudebar.infrastructure.network

/**
 * Cross-platform interface for HTTP requests.
 * Uses Ktor under the hood for multiplatform support.
 */
interface NetworkClient {
    /**
     * Performs an HTTP GET request and returns the response body as a string.
     */
    suspend fun get(
        url: String,
        headers: Map<String, String> = emptyMap()
    ): NetworkResponse

    /**
     * Performs an HTTP POST request with the given body.
     */
    suspend fun post(
        url: String,
        body: String,
        headers: Map<String, String> = emptyMap()
    ): NetworkResponse
}

/**
 * Represents an HTTP response.
 */
data class NetworkResponse(
    val statusCode: Int,
    val body: String,
    val headers: Map<String, List<String>>
)
