package com.tddworks.claudebar.infrastructure.probes.gemini

import com.tddworks.claudebar.infrastructure.platform.FileSystem
import kotlinx.serialization.json.Json
import kotlinx.serialization.json.JsonObject
import kotlinx.serialization.json.double
import kotlinx.serialization.json.jsonPrimitive

/**
 * Default implementation of GeminiCredentialsProvider that reads
 * OAuth credentials from ~/.gemini/oauth_creds.json
 */
class DefaultGeminiCredentialsProvider(
    private val json: Json = Json { ignoreUnknownKeys = true }
) : GeminiCredentialsProvider {

    companion object {
        private const val CREDENTIALS_PATH = "/.gemini/oauth_creds.json"
    }

    override suspend fun hasCredentials(): Boolean {
        val path = FileSystem.homeDirectory() + CREDENTIALS_PATH
        return FileSystem.fileExists(path)
    }

    override suspend fun loadCredentials(): GeminiCredentials? {
        val path = FileSystem.homeDirectory() + CREDENTIALS_PATH
        val content = FileSystem.readFile(path) ?: return null

        return try {
            val jsonObject = json.decodeFromString<JsonObject>(content)

            GeminiCredentials(
                accessToken = jsonObject["access_token"]?.jsonPrimitive?.content,
                refreshToken = jsonObject["refresh_token"]?.jsonPrimitive?.content,
                expiryDate = jsonObject["expiry_date"]?.jsonPrimitive?.double?.toLong()
            )
        } catch (e: Exception) {
            null
        }
    }
}
