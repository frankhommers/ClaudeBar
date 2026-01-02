package com.tddworks.claudebar.infrastructure.cli

import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import kotlinx.coroutines.withTimeoutOrNull
import java.io.File
import java.util.concurrent.TimeUnit
import kotlin.time.Duration

/**
 * JVM implementation of CLIExecutor using ProcessBuilder.
 */
class JvmCLIExecutor : CLIExecutor {

    override fun locate(binary: String): String? {
        // Check common paths
        val paths = listOf(
            "/usr/local/bin/$binary",
            "/usr/bin/$binary",
            "/opt/homebrew/bin/$binary",
            System.getProperty("user.home") + "/.local/bin/$binary"
        )

        for (path in paths) {
            if (File(path).exists()) {
                return path
            }
        }

        // Try 'which' command
        return try {
            val process = ProcessBuilder("which", binary)
                .redirectErrorStream(true)
                .start()

            val output = process.inputStream.bufferedReader().readText().trim()
            val exitCode = process.waitFor()

            if (exitCode == 0 && output.isNotEmpty()) output else null
        } catch (e: Exception) {
            null
        }
    }

    override suspend fun execute(
        binary: String,
        args: List<String>,
        input: String?,
        timeout: Duration,
        workingDirectory: String?,
        autoResponses: Map<String, String>
    ): CLIResult = withContext(Dispatchers.IO) {
        val command = mutableListOf(binary)
        command.addAll(args)

        val processBuilder = ProcessBuilder(command)
            .redirectErrorStream(true)

        workingDirectory?.let {
            processBuilder.directory(File(it))
        }

        val process = processBuilder.start()

        // Write input if provided
        if (input != null) {
            process.outputStream.bufferedWriter().use { writer ->
                writer.write(input)
                writer.flush()
            }
        }

        // Read output
        val output = StringBuilder()

        val result = if (timeout.isFinite()) {
            withTimeoutOrNull(timeout) {
                output.append(process.inputStream.bufferedReader().readText())
                process.waitFor()
            }
        } else {
            output.append(process.inputStream.bufferedReader().readText())
            process.waitFor()
        }

        if (result == null) {
            process.destroyForcibly()
            CLIResult(output = "Timeout", exitCode = -1)
        } else {
            CLIResult(
                output = output.toString(),
                exitCode = process.exitValue()
            )
        }
    }
}
