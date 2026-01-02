package com.tddworks.claudebar.infrastructure.platform

import kotlinx.cinterop.ExperimentalForeignApi
import kotlinx.cinterop.refTo
import kotlinx.cinterop.toKString
import platform.posix.F_OK
import platform.posix._access
import platform.posix.fclose
import platform.posix.fgets
import platform.posix.fopen
import platform.posix.getenv

@OptIn(ExperimentalForeignApi::class)
actual object FileSystem {
    actual fun homeDirectory(): String {
        // Windows uses USERPROFILE for home directory
        return getenv("USERPROFILE")?.toKString()
            ?: getenv("HOME")?.toKString()
            ?: ""
    }

    actual fun fileExists(path: String): Boolean {
        return _access(path, F_OK) == 0
    }

    actual fun readFile(path: String): String? {
        val file = fopen(path, "r") ?: return null
        val content = StringBuilder()
        val buffer = ByteArray(4096)

        try {
            while (true) {
                val line = fgets(buffer.refTo(0), buffer.size, file)
                if (line == null) break
                content.append(line.toKString())
            }
        } finally {
            fclose(file)
        }

        return content.toString()
    }
}
