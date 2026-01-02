package com.tddworks.claudebar.infrastructure.network

import io.ktor.client.HttpClient
import io.ktor.client.plugins.HttpTimeout
import io.ktor.client.plugins.contentnegotiation.ContentNegotiation
import io.ktor.client.plugins.logging.LogLevel
import io.ktor.client.plugins.logging.Logging
import io.ktor.serialization.kotlinx.json.json
import kotlinx.serialization.json.Json

/**
 * Factory for creating Ktor HttpClient instances with common configuration.
 * Platform-specific engines are configured via expect/actual.
 */
expect fun createHttpClient(
    json: Json = defaultJson,
    enableLogging: Boolean = false
): HttpClient

/**
 * Default JSON configuration for API responses.
 */
val defaultJson = Json {
    ignoreUnknownKeys = true
    isLenient = true
    prettyPrint = false
    encodeDefaults = true
}

/**
 * Configures common plugins for the HttpClient.
 * Called by platform-specific implementations.
 */
internal fun HttpClient.configureCommon(
    json: Json,
    enableLogging: Boolean
): HttpClient {
    return config {
        install(ContentNegotiation) {
            json(json)
        }
        install(HttpTimeout) {
            requestTimeoutMillis = 30_000
            connectTimeoutMillis = 10_000
            socketTimeoutMillis = 30_000
        }
        if (enableLogging) {
            install(Logging) {
                level = LogLevel.BODY
            }
        }
    }
}
