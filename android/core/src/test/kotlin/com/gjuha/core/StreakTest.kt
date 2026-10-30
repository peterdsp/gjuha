package com.gjuha.core

import java.time.LocalDate
import kotlin.test.Test
import kotlin.test.assertEquals

/**
 * The streak rule.
 *
 * It is the number most visible to a learner and the one they would most
 * resent being wrong, so every branch is pinned here rather than left to be
 * checked by playing the app.
 */
class StreakTest {

    private val today = LocalDate.of(2026, 10, 30)

    @Test
    fun `the first ever day of study starts the streak at one`() {
        assertEquals(1, advanceStreak(current = 0, lastActivity = null, today = today))
    }

    /** A streak counts days, not sessions. */
    @Test
    fun `studying twice in one day does not count twice`() {
        assertEquals(4, advanceStreak(current = 4, lastActivity = today, today = today))
    }

    @Test
    fun `the next day advances it`() {
        assertEquals(
            5,
            advanceStreak(current = 4, lastActivity = today.minusDays(1), today = today),
        )
    }

    /**
     * Restarts at one rather than zero: the day being recorded is itself a day
     * of study, so a learner coming back after a break is on day one, not day
     * none.
     */
    @Test
    fun `a missed day restarts the streak at one`() {
        assertEquals(
            1,
            advanceStreak(current = 9, lastActivity = today.minusDays(2), today = today),
        )
        assertEquals(
            1,
            advanceStreak(current = 30, lastActivity = today.minusDays(90), today = today),
        )
    }

    /**
     * A clock that has gone backwards, from a timezone change or a user
     * setting, must not be treated as consecutive.
     */
    @Test
    fun `activity dated in the future restarts rather than advancing`() {
        assertEquals(
            1,
            advanceStreak(current = 6, lastActivity = today.plusDays(1), today = today),
        )
    }

    @Test
    fun `a month boundary is still just the next day`() {
        val firstOfMonth = LocalDate.of(2026, 11, 1)
        assertEquals(
            8,
            advanceStreak(
                current = 7,
                lastActivity = LocalDate.of(2026, 10, 31),
                today = firstOfMonth,
            ),
        )
    }
}
