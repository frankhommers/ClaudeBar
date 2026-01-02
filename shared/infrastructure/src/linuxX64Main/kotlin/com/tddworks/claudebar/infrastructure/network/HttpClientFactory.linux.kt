package com.tddworks.claudebar.infrastructure.network

import io.ktor.client.HttpClient
import io.ktor.client.engine.curl.Curl
import kotlinx.serialization.json.Json

/**
 * Linux implementation using Curl engine.
 */
actual fun createHttpClient(
    json: Json,
    enableLogging: Boolean
): HttpClient {
    return HttpClient(Curl) {
        engine {
            sslVerify = true
        }
    }.configureCommon(json, enableLogging)
}
