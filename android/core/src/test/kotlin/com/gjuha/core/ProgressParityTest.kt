package com.gjuha.core

import java.time.LocalDate
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertFalse
import kotlin.test.assertNotNull
import kotlin.test.assertNull
import kotlin.test.assertTrue

/** Parity for the daily goal, mirroring the Swift `DailyGoalTests`. */
class DailyGoalParityTest {

    private val today: LocalDate = LocalDate.of(2026, 1, 15)

    @Test
    fun `the goal is derived from the chosen minutes`() {
        for (goal in LearningGoal.entries) {
            assertEquals(goal.minutesPerDay * LearningGoal.XP_PER_MINUTE, goal.dailyXpGoal)
            assertTrue(goal.dailyXpGoal > 0)
        }
        // The exact figures the iOS tests pin, so the two cannot drift.
        assertEquals(60, LearningGoal.CASUAL.dailyXpGoal)
        assertEquals(120, LearningGoal.REGULAR.dailyXpGoal)
        assertEquals(180, LearningGoal.SERIOUS.dailyXpGoal)
        assertEquals(240, LearningGoal.INTENSE.dailyXpGoal)
    }

    @Test
    fun `a more ambitious goal asks for more xp`() {
        assertTrue(LearningGoal.CASUAL.dailyXpGoal < LearningGoal.REGULAR.dailyXpGoal)
        assertTrue(LearningGoal.REGULAR.dailyXpGoal < LearningGoal.SERIOUS.dailyXpGoal)
        assertTrue(LearningGoal.SERIOUS.dailyXpGoal < LearningGoal.INTENSE.dailyXpGoal)
    }

    /** The persisted identity must survive, or every learner's goal resets. */
    @Test
    fun `raw values are the stored identity`() {
        assertEquals(LearningGoal.REGULAR, LearningGoal.fromRawValue("regular"))
        assertEquals(LearningGoal.CASUAL, LearningGoal.fromRawValue(null))
        assertEquals(LearningGoal.CASUAL, LearningGoal.fromRawValue("nonsense"))
    }

    @Test
    fun `xp accumulates within the same day`() {
        var xp = DailyXp()
        xp = xp.adding(30, today)
        xp = xp.adding(15, today)
        assertEquals(45, xp.earnedOn(today))
    }

    /** The rollover is a read-time comparison, so it needs no timer. */
    @Test
    fun `yesterdays xp reads as zero today`() {
        val yesterday = DailyXp(120, today.minusDays(1))
        assertEquals(0, yesterday.earnedOn(today))
        assertEquals(120, yesterday.earnedOn(today.minusDays(1)))
    }

    @Test
    fun `adding after a rollover starts from zero`() {
        val stale = DailyXp(120, today.minusDays(1))
        val fresh = stale.adding(10, today)
        assertEquals(10, fresh.earnedOn(today))
    }

    @Test
    fun `goal progress is clamped but the raw figure is not`() {
        val stats = UserStats(xpToday = 300, dailyGoalXp = 120)
        assertEquals(1.0, stats.dailyGoalProgress, "a ring cannot overfill")
        assertEquals(300, stats.xpToday, "but the learner still sees what they did")
        assertTrue(stats.hasMetDailyGoal)
    }

    @Test
    fun `goal progress is proportional below the goal`() {
        val stats = UserStats(xpToday = 60, dailyGoalXp = 120)
        assertEquals(0.5, stats.dailyGoalProgress)
        assertFalse(stats.hasMetDailyGoal)
    }

    /** Reachable through a decoded payload that predates the field. */
    @Test
    fun `a zero goal is neither met nor divided by`() {
        val stats = UserStats(xpToday = 0, dailyGoalXp = 0)
        assertEquals(0.0, stats.dailyGoalProgress)
        assertFalse(stats.hasMetDailyGoal)
    }
}

/** Parity for the achievement catalogue, mirroring `AchievementCatalogTests`. */
class AchievementParityTest {

    private fun stats(
        streak: Int = 0,
        lessons: Int = 0,
        xp: Int = 0,
        seen: Int = 0,
        mastered: Int = 0,
    ) = UserStats(
        currentStreak = streak,
        totalXp = xp,
        wordsSeen = seen,
        lessonsCompleted = lessons,
        wordsPracticed = mastered,
        wordsMastered = mastered,
    )

    /** The ids are persisted, so they are part of the contract with iOS. */
    @Test
    fun `the catalogue matches the iOS ids exactly`() {
        assertEquals(
            listOf(
                "streak.3", "streak.7", "streak.30", "streak.100",
                "lessons.1", "lessons.10", "lessons.50",
                "xp.500", "xp.2500", "seen.100",
                "mastered.25", "mastered.100",
            ),
            AchievementCatalog.all.map { it.id },
        )
    }

    @Test
    fun `ids are unique and thresholds positive`() {
        val ids = AchievementCatalog.all.map { it.id }
        assertEquals(ids.size, ids.toSet().size, "duplicate achievement id")
        assertTrue(AchievementCatalog.all.all { it.threshold > 0 })
    }

    @Test
    fun `nothing is unlocked by a fresh account`() {
        assertTrue(AchievementCatalog.unlockedBy(UserStats.EMPTY).isEmpty())
    }

    @Test
    fun `a milestone unlocks exactly at its threshold`() {
        val weekly = AchievementCatalog.achievement("streak.7")
        assertNotNull(weekly)
        assertTrue(weekly.isUnlockedBy(stats(streak = 7)))
        assertFalse(weekly.isUnlockedBy(stats(streak = 6)))
    }

    @Test
    fun `better stats never unlock fewer milestones`() {
        val modest = AchievementCatalog.unlockedBy(
            stats(streak = 3, lessons = 1, xp = 500, seen = 100, mastered = 25)
        ).map { it.id }.toSet()
        val better = AchievementCatalog.unlockedBy(
            stats(streak = 30, lessons = 50, xp = 2_500, seen = 400, mastered = 100)
        ).map { it.id }.toSet()

        assertTrue(modest.all { it in better })
        assertTrue(better.size > modest.size)
    }

    /** The honesty rule: exposure is not mastery. */
    @Test
    fun `mastery milestones ignore mere exposure`() {
        val seenNotKept = AchievementCatalog.unlockedBy(stats(seen = 4_000, mastered = 0))
            .map { it.id }.toSet()
        assertFalse("mastered.25" in seenNotKept)
        assertFalse("mastered.100" in seenNotKept)
        assertTrue("seen.100" in seenNotKept, "breadth is still its own milestone")
    }

    @Test
    fun `progress is clamped to one`() {
        val far = stats(streak = 10_000)
        for (a in AchievementCatalog.all) {
            assertTrue(a.progressIn(far) in 0.0..1.0)
            assertTrue(a.progressValueIn(far) <= a.threshold)
        }
    }

    @Test
    fun `next up picks the closest unreached milestone`() {
        val almostAWeek = stats(streak = 6, lessons = 1, xp = 10, seen = 5)
        assertEquals("streak.7", AchievementCatalog.nextUp(almostAWeek)?.id)
    }

    @Test
    fun `next up is offered to a brand new learner and nil only when complete`() {
        assertNotNull(AchievementCatalog.nextUp(UserStats.EMPTY))
        val everything = stats(streak = 500, lessons = 500, xp = 500_000, seen = 5_000, mastered = 5_000)
        assertEquals(AchievementCatalog.all.size, AchievementCatalog.unlockedBy(everything).size)
        assertNull(AchievementCatalog.nextUp(everything))
    }

    @Test
    fun `evaluation is deterministic`() {
        val sample = stats(streak = 9, lessons = 12, xp = 900, seen = 140, mastered = 30)
        assertEquals(
            AchievementCatalog.unlockedBy(sample).map { it.id },
            AchievementCatalog.unlockedBy(sample).map { it.id },
        )
    }
}
