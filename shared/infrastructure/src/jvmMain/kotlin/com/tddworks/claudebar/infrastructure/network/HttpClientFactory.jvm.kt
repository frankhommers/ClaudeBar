package com.tddworks.claudebar.infrastructure.network

import io.ktor.client.HttpClient
import io.ktor.client.engine.okhttp.OkHttp
import kotlinx.serialization.json.Json

/**
 * JVM implementation using OkHttp engine.
 */
actual fun createHttpClient(
    json: Json,
    enableLogging: Boolean
): HttpClient {
    return HttpClient(OkHttp) {
        engine {
            config {
                followRedirects(true)
            }
        }
    }.configureCommon(json, enableLogging)
}
