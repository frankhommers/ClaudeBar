package com.tddworks.claudebar.infrastructure.network

import io.ktor.client.HttpClient
import io.ktor.client.request.get
import io.ktor.client.request.headers
import io.ktor.client.request.post
import io.ktor.client.request.setBody
import io.ktor.client.statement.HttpResponse
import io.ktor.client.statement.bodyAsText
import io.ktor.http.ContentType
import io.ktor.http.contentType

/**
 * Ktor-based implementation of NetworkClient for cross-platform HTTP requests.
 */
class KtorNetworkClient(
    private val httpClient: HttpClient
) : NetworkClient {

    override suspend fun get(
        url: String,
        headers: Map<String, String>
    ): NetworkResponse {
        val response = httpClient.get(url) {
            headers {
                headers.forEach { (key, value) ->
                    append(key, value)
                }
            }
        }
        return response.toNetworkResponse()
    }

    override suspend fun post(
        url: String,
        body: String,
        headers: Map<String, String>
    ): NetworkResponse {
        val response = httpClient.post(url) {
            contentType(ContentType.Application.Json)
            headers {
                headers.forEach { (key, value) ->
                    append(key, value)
                }
            }
            setBody(body)
        }
        return response.toNetworkResponse()
    }

    private suspend fun HttpResponse.toNetworkResponse(): NetworkResponse {
        return NetworkResponse(
            statusCode = status.value,
            body = bodyAsText(),
            headers = headers.entries().associate { (key, values) -> key to values }
        )
    }
}
