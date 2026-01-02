package com.tddworks.claudebar.infrastructure.platform

/**
 * Cross-platform file system abstraction.
 * Used for reading configuration files like Gemini credentials.
 */
expect object FileSystem {
    /**
     * Returns the user's home directory path.
     */
    fun homeDirectory(): String

    /**
     * Checks if a file exists at the given path.
     */
    fun fileExists(path: String): Boolean

    /**
     * Reads the contents of a file as a string.
     * Returns null if the file doesn't exist or can't be read.
     */
    fun readFile(path: String): String?
}
