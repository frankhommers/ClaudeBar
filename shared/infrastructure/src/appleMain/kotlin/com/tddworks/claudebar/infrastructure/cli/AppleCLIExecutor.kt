package com.tddworks.claudebar.infrastructure.cli

import kotlinx.cinterop.ExperimentalForeignApi
import kotlinx.cinterop.toKString
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import platform.Foundation.NSFileManager
import platform.Foundation.NSPipe
import platform.Foundation.NSString
import platform.Foundation.NSTask
import platform.Foundation.NSURL
import platform.Foundation.NSUTF8StringEncoding
import platform.Foundation.create
import platform.Foundation.dataUsingEncoding
import platform.Foundation.fileHandleForReading
import platform.Foundation.fileHandleForWriting
import platform.Foundation.readDataToEndOfFile
import platform.posix.getenv
import kotlin.time.Duration

/**
 * macOS/iOS implementation of CLIExecutor using NSTask.
 */
@OptIn(ExperimentalForeignApi::class)
class AppleCLIExecutor : CLIExecutor {

    override fun locate(binary: String): String? {
        val paths = listOf(
            "/usr/local/bin/$binary",
            "/usr/bin/$binary",
            "/opt/homebrew/bin/$binary",
            "${getenv("HOME")?.toKString() ?: ""}/.local/bin/$binary"
        )

        for (path in paths) {
            if (NSFileManager.defaultManager.fileExistsAtPath(path)) {
                return path
            }
        }

        // Try 'which' command
        return try {
            val result = executeSync(
                binary = "/usr/bin/which",
                args = listOf(binary),
                timeout = Duration.parse("5s")
            )
            if (result.exitCode == 0) result.output.trim() else null
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
        executeSync(binary, args, input, timeout, workingDirectory)
    }

    private fun executeSync(
        binary: String,
        args: List<String> = emptyList(),
        input: String? = null,
        timeout: Duration = Duration.INFINITE,
        workingDirectory: String? = null
    ): CLIResult {
        val task = NSTask()
        task.setLaunchPath(binary)
        task.setArguments(args)

        workingDirectory?.let {
            task.setCurrentDirectoryURL(NSURL.fileURLWithPath(it))
        }

        val outputPipe = NSPipe()
        task.setStandardOutput(outputPipe)
        task.setStandardError(outputPipe)

        if (input != null) {
            val inputPipe = NSPipe()
            task.setStandardInput(inputPipe)

            val inputData = NSString.create(string = input)
                .dataUsingEncoding(NSUTF8StringEncoding)

            if (inputData != null) {
                inputPipe.fileHandleForWriting.writeData(inputData)
                inputPipe.fileHandleForWriting.closeFile()
            }
        }

        task.launch()
        task.waitUntilExit()

        val outputData = outputPipe.fileHandleForReading.readDataToEndOfFile()
        val output = NSString.create(data = outputData, encoding = NSUTF8StringEncoding)?.toString() ?: ""

        return CLIResult(
            output = output,
            exitCode = task.terminationStatus
        )
    }
}
