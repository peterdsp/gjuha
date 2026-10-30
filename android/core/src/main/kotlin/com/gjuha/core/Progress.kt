package com.gjuha.core

import java.time.LocalDate

/**
 * How much the learner committed to per day. Ported from iOS `LearningGoal`.
 *
 * [rawValue] is the persisted identity and must never change: it is what is
 * written to storage on both platforms.
 */
enum class LearningGoal(val rawValue: String, val minutesPerDay: Int) {
    CASUAL("casual", 5),
    REGULAR("regular", 10),
    SERIOUS("serious", 15),
    INTENSE("intense", 20);

    /**
     * XP per day that counts as meeting this goal.
     *
     * Derived from the chosen minutes rather than hand-tuned per case, so the
     * two can never disagree. The rate comes from what the engine awards:
     * exercises are worth 10 to 15 XP, a lesson runs 8 to 10 of them with a
     * combo bonus every third correct answer, and a lesson takes about five
     * minutes.
     *
     * Deliberately reachable through reviews alone, exactly as on iOS: a day
     * spent strengthening old words still meets the goal. Making it lesson-only
     * would push learners past material they have not retained.
     */
    val dailyXpGoal: Int get() = minutesPerDay * XP_PER_MINUTE

    companion object {
        /** XP an engaged learner earns per minute of study. */
        const val XP_PER_MINUTE = 12

        fun fromRawValue(raw: String?): LearningGoal =
            entries.firstOrNull { it.rawValue == raw } ?: CASUAL
    }
}

/**
 * The learner's figures, kept deliberately separate so none of them overstates
 * another. Ported from iOS `UserStats`.
 *
 * The three vocabulary numbers are a ladder and must stay distinct:
 * [wordsSeen] is exposure, [wordsPracticed] is in the review schedule, and
 * [wordsMastered] is the only one presented as mastery.
 */
data class UserStats(
    val currentStreak: Int = 0,
    val totalXp: Int = 0,
    val wordsSeen: Int = 0,
    val lessonsCompleted: Int = 0,
    val wordsPracticed: Int = 0,
    val wordsMastered: Int = 0,
    val xpToday: Int = 0,
    val dailyGoalXp: Int = LearningGoal.CASUAL.dailyXpGoal,
) {
    /**
     * Today's progress toward the goal, clamped to 0..1.
     *
     * Clamped because the ring that draws it cannot overfill, while [xpToday]
     * is not clamped: a learner who doubles their goal should see that they did.
     */
    val dailyGoalProgress: Double
        get() = if (dailyGoalXp <= 0) 0.0 else minOf(1.0, xpToday.toDouble() / dailyGoalXp)

    val hasMetDailyGoal: Boolean get() = dailyGoalXp > 0 && xpToday >= dailyGoalXp

    companion object {
        val EMPTY = UserStats()
    }
}

/**
 * XP earned since local midnight, stored as a value plus the day it belongs to.
 *
 * The rollover is a read-time comparison rather than something that has to be
 * reset: a stored day that is not today reads as zero. That needs no timer, no
 * background work, and no assumption that the app was open at midnight, and it
 * follows the device across time zones for the same reason the streak does.
 * Ported from the iOS `ProgressStore` behaviour.
 */
data class DailyXp(val amount: Int = 0, val day: LocalDate? = null) {

    fun earnedOn(today: LocalDate): Int = if (day == today) amount else 0

    fun adding(xp: Int, today: LocalDate): DailyXp {
        if (xp <= 0) return this
        return DailyXp(earnedOn(today) + xp, today)
    }
}
