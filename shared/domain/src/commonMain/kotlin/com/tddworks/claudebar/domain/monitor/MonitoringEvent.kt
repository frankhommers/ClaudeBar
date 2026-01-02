package com.tddworks.claudebar.domain.monitor

/**
 * Events emitted during continuous monitoring
 */
sealed class MonitoringEvent {
    /** A refresh cycle completed */
    data object Refreshed : MonitoringEvent()

    /** An error occurred during refresh for a provider */
    data class Error(val providerId: String, val error: Throwable) : MonitoringEvent()
}
