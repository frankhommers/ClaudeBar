package com.tddworks.claudebar.infrastructure.network

import io.ktor.client.HttpClient
import io.ktor.client.engine.winhttp.WinHttp
import kotlinx.serialization.json.Json

/**
 * Windows implementation using WinHttp engine.
 */
actual fun createHttpClient(
    json: Json,
    enableLogging: Boolean
): HttpClient {
    return HttpClient(WinHttp).configureCommon(json, enableLogging)
}
