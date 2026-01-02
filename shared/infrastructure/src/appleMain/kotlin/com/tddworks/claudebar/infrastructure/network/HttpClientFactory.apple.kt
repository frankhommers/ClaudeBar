package com.tddworks.claudebar.infrastructure.network

import io.ktor.client.HttpClient
import io.ktor.client.engine.darwin.Darwin
import kotlinx.serialization.json.Json

/**
 * Apple platforms implementation using Darwin engine.
 * Works on macOS, iOS, tvOS, watchOS.
 */
actual fun createHttpClient(
    json: Json,
    enableLogging: Boolean
): HttpClient {
    return HttpClient(Darwin) {
        engine {
            configureRequest {
                setAllowsCellularAccess(true)
            }
        }
    }.configureCommon(json, enableLogging)
}
