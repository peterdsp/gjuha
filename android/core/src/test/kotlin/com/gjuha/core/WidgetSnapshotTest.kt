package com.gjuha.core

import java.time.LocalDate
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertFalse
import kotlin.test.assertNotNull
import kotlin.test.assertNull
import kotlin.test.assertTrue

/**
 * The widget projection.
 *
 * The rule under test is the one that keeps the widget honest: a figure that
 * means something only on the day it was computed may not be shown on a later
 * day. A learner acts on "3 words due", so showing yesterday's 3 is worse than
 * showing nothing.
 */
class WidgetSnapshotTest {

    private val monday = LocalDate.of(2026, 10, 26)
    private val tuesday = LocalDate.of(2026, 10, 27)

    private fun snapshot(day: LocalDate? = monday) = WidgetSnapshot(
        currentStreak = 4,
        totalXp = 520,
        dueReviewCount = 3,
        wordsMastered = 2,
        nextLessonTitle = "Numbers & time",
        practicedToday = true,
        xpToday = 40,
        dailyGoalXp = 120,
        generatedOn = day,
    )

    @Test
    fun `a projection is fresh on the day it was built`() {
        assertFalse(snapshot().isStale(monday))
        val q = snapshot().quotable(monday)
        assertEquals(3, q.dueReviewCount)
        assertEquals(40, q.xpToday)
        assertEquals(true, q.practicedToday)
    }

    @Test
    fun `day-sensitive counts are withheld once the day turns`() {
        assertTrue(snapshot().isStale(tuesday))
        val q = snapshot().quotable(tuesday)
        assertNull(q.dueReviewCount, "yesterday's due count must not be quoted")
        assertNull(q.xpToday, "yesterday's XP must not be quoted as today's")
        assertNull(q.practicedToday, "practised-today must not survive the night")
        assertNull(q.dailyGoalXp)
    }

    /** A streak and a lifetime total do not expire at midnight. */
    @Test
    fun `figures that are not day-sensitive survive staleness`() {
        val q = snapshot().quotable(tuesday)
        assertEquals(4, q.currentStreak)
        assertEquals(520, q.totalXp)
        assertEquals(2, q.wordsMastered)
        assertEquals("Numbers & time", q.nextLessonTitle)
    }

    /**
     * Never written is not the same as out of date. A placeholder must not be
     * reported stale, or the widget would hide figures it never had.
     */
    @Test
    fun `an unwritten projection is a placeholder, not a stale one`() {
        val empty = WidgetSnapshot()
        assertFalse(empty.isRealData)
        assertFalse(empty.isStale(tuesday))
    }

    @Test
    fun `goal progress is clamped and survives a zero goal`() {
        assertEquals(0.0, WidgetSnapshot(dailyGoalXp = 0, xpToday = 50).dailyGoalProgress)
        assertEquals(1.0, snapshot().copy(xpToday = 999).dailyGoalProgress)
        assertEquals(0.25, snapshot().copy(xpToday = 30, dailyGoalXp = 120).dailyGoalProgress)
    }

    @Test
    fun `a learner with everything done has no next lesson rather than a wrong one`() {
        val done = snapshot().copy(nextLessonTitle = null)
        assertNull(done.quotable(monday).nextLessonTitle)
        assertNotNull(done.quotable(monday).dueReviewCount)
    }
}
