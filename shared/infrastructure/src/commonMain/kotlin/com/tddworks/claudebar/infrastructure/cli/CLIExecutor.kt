package com.tddworks.claudebar.infrastructure.cli

import kotlin.time.Duration

/**
 * Result of executing a CLI command.
 */
data class CLIResult(
    val output: String,
    val exitCode: Int
)

/**
 * Interface for executing CLI commands.
 * Platform-specific implementations handle the actual process execution.
 */
interface CLIExecutor {
    /**
     * Finds a tool on the system. Returns the path if found, null otherwise.
     */
    fun locate(binary: String): String?

    /**
     * Runs a CLI command and returns the result.
     *
     * @param binary The CLI tool to run
     * @param args Command-line arguments
     * @param input Text to send to the command's stdin
     * @param timeout Maximum time to wait
     * @param workingDirectory Directory to run in (null = inherited)
     * @param autoResponses Automatic responses to prompts (prompt text → response to send)
     */
    suspend fun execute(
        binary: String,
        args: List<String> = emptyList(),
        input: String? = null,
        timeout: Duration = Duration.INFINITE,
        workingDirectory: String? = null,
        autoResponses: Map<String, String> = emptyMap()
    ): CLIResult
}
