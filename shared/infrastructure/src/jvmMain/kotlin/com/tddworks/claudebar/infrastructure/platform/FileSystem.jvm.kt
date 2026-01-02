package com.tddworks.claudebar.infrastructure.platform

import java.io.File

actual object FileSystem {
    actual fun homeDirectory(): String {
        return System.getProperty("user.home") ?: ""
    }

    actual fun fileExists(path: String): Boolean {
        return File(path).exists()
    }

    actual fun readFile(path: String): String? {
        return try {
            File(path).readText()
        } catch (e: Exception) {
            null
        }
    }
}
