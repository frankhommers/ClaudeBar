package com.tddworks.claudebar.domain.model

import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertTrue

class UsageQuotaTest {

    @Test
    fun `quota status is HEALTHY when percent remaining is above 25`() {
        val quota = UsageQuota(
            percentRemaining = 50.0,
            quotaType = QuotaType.Session,
            providerId = "test"
        )

        assertEquals(QuotaStatus.HEALTHY, quota.status)
    }

    @Test
    fun `quota status is LOW when percent remaining is between 10 and 25`() {
        val quota = UsageQuota(
            percentRemaining = 15.0,
            quotaType = QuotaType.Session,
            providerId = "test"
        )

        assertEquals(QuotaStatus.LOW, quota.status)
    }

    @Test
    fun `quota status is CRITICAL when percent remaining is between 5 and 10`() {
        val quota = UsageQuota(
            percentRemaining = 7.0,
            quotaType = QuotaType.Session,
            providerId = "test"
        )

        assertEquals(QuotaStatus.CRITICAL, quota.status)
    }

    @Test
    fun `quota status is EXHAUSTED when percent remaining is below 5`() {
        val quota = UsageQuota(
            percentRemaining = 2.0,
            quotaType = QuotaType.Session,
            providerId = "test"
        )

        assertEquals(QuotaStatus.EXHAUSTED, quota.status)
    }

    @Test
    fun `quotas are comparable by percentRemaining`() {
        val low = UsageQuota(percentRemaining = 10.0, quotaType = QuotaType.Session, providerId = "test")
        val high = UsageQuota(percentRemaining = 80.0, quotaType = QuotaType.Weekly, providerId = "test")

        assertTrue(low < high)
    }
}
