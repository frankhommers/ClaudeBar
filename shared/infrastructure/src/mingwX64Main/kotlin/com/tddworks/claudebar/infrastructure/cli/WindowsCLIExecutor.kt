package com.tddworks.claudebar.infrastructure.cli

import kotlinx.cinterop.ExperimentalForeignApi
import kotlinx.cinterop.refTo
import kotlinx.cinterop.toKString
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import platform.posix.F_OK
import platform.posix._access
import platform.posix._pclose
import platform.posix._popen
import platform.posix.fgets
import platform.posix.getenv
import kotlin.time.Duration

/**
 * Windows implementation of CLIExecutor using _popen.
 */
@OptIn(ExperimentalForeignApi::class)
class WindowsCLIExecutor : CLIExecutor {

    override fun locate(binary: String): String? {
        val userProfile = getenv("USERPROFILE")?.toKString() ?: ""
        val localAppData = getenv("LOCALAPPDATA")?.toKString() ?: ""

        // Add .exe extension if not present
        val executableName = if (binary.endsWith(".exe")) binary else "$binary.exe"

        val paths = listOf(
            "$localAppData\\Programs\\$binary\\$executableName",
            "$userProfile\\.local\\bin\\$executableName",
            "C:\\Program Files\\$binary\\$executableName",
            "C:\\Program Files (x86)\\$binary\\$executableName"
        )

        for (path in paths) {
            if (_access(path, F_OK) == 0) {
                return path
            }
        }

        // Try 'where' command (Windows equivalent of 'which')
        return try {
            val result = executeCommand("where $binary")
            if (result.exitCode == 0) result.output.lines().firstOrNull()?.trim() else null
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
    ): CLIResult = withContext(Dispatchers.Default) {
        val command = buildString {
            if (workingDirectory != null) {
                append("cd /d \"$workingDirectory\" && ")
            }
            append(binary)
            args.forEach { arg ->
                append(" \"$arg\"")
            }
            if (input != null) {
                append(" < nul")
            }
        }

        executeCommand(command)
    }

    private fun executeCommand(command: String): CLIResult {
        val fp = _popen(command, "r") ?: return CLIResult("Failed to execute", -1)

        val output = StringBuilder()
        val buffer = ByteArray(4096)

        try {
            while (true) {
                val line = fgets(buffer.refTo(0), buffer.size, fp)
                if (line == null) break
                output.append(line.toKString())
            }
        } finally {
            val exitCode = _pclose(fp)
            return CLIResult(output.toString(), exitCode)
        }
    }
}
