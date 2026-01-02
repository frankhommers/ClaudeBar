package com.tddworks.claudebar.domain.provider

/**
 * Repository interface for AI providers.
 * Defines the interface for managing a collection of providers.
 */
interface AIProviderRepository {
    /** All registered providers */
    val all: List<AIProvider>

    /** Only enabled providers (filtered by isEnabled state) */
    val enabled: List<AIProvider>

    /** Finds a provider by its ID */
    fun provider(id: String): AIProvider?

    /** Adds a provider if not already present */
    fun add(provider: AIProvider)

    /** Removes a provider by ID */
    fun remove(id: String)
}
