package com.tddworks.claudebar.domain.monitor

import com.tddworks.claudebar.domain.model.QuotaStatus

/**
 * Domain interface for alerting users about quota changes.
 * Implementations decide how to alert (notifications, sounds, etc.).
 */
interface QuotaAlerter {
    /**
     * Requests permission to send alerts to the user.
     * Returns true if permission was granted.
     */
    suspend fun requestPermission(): Boolean

    /**
     * Called when a provider's quota status changes.
     * Implementations should alert users if the status degraded.
     */
    suspend fun alert(providerId: String, previousStatus: QuotaStatus, currentStatus: QuotaStatus)
}
