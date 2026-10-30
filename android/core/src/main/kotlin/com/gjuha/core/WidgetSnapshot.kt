package com.gjuha.core

import java.time.LocalDate

/**
 * What the home screen widget is allowed to say.
 *
 * The widget never computes anything. It renders a projection the app writes,
 * derived from the same stores the Profile screen reads, so the two can never
 * disagree about a number.
 *
 * [generatedOn] being null means the app has never written one, which is the
 * placeholder state rather than a learner with nothing.
 */
data class WidgetSnapshot(
    val currentStreak: Int = 0,
    val totalXp: Int = 0,
    val dueReviewCount: Int = 0,
    val wordsMastered: Int = 0,
    val nextLessonTitle: String? = null,
    val practicedToday: Boolean = false,
    val xpToday: Int = 0,
    val dailyGoalXp: Int = 0,
    val generatedOn: LocalDate? = null,
) {
    /** False before the app has ever written a projection. */
    val isRealData: Boolean get() = generatedOn != null

    /**
     * Whether the day-sensitive counts can still be trusted on [today].
     *
     * `dueReviewCount`, `practicedToday`, `xpToday` and the goal are all
     * relative to a calendar day: more words fall due at midnight and
     * "practised today" resets. A widget that keeps showing yesterday's figures
     * is worse than one that shows none, because the learner acts on them.
     */
    fun isStale(today: LocalDate): Boolean {
        val day = generatedOn ?: return false
        return day != today
    }

    /** Today's progress toward the goal, clamped for a ring. */
    val dailyGoalProgress: Double
        get() = if (dailyGoalXp <= 0) 0.0 else minOf(1.0, xpToday.toDouble() / dailyGoalXp)

    /**
     * The counts a widget may quote on [today].
     *
     * Returns null for every day-sensitive figure once the projection is stale,
     * so a caller cannot accidentally render one. The streak, the lifetime XP
     * and the mastery count are not day-sensitive and survive.
     */
    fun quotable(today: LocalDate): Quotable = Quotable(
        currentStreak = currentStreak,
        totalXp = totalXp,
        wordsMastered = wordsMastered,
        nextLessonTitle = nextLessonTitle,
        dueReviewCount = if (isStale(today)) null else dueReviewCount,
        practicedToday = if (isStale(today)) null else practicedToday,
        xpToday = if (isStale(today)) null else xpToday,
        dailyGoalXp = if (isStale(today)) null else dailyGoalXp,
    )

    data class Quotable(
        val currentStreak: Int,
        val totalXp: Int,
        val wordsMastered: Int,
        val nextLessonTitle: String?,
        val dueReviewCount: Int?,
        val practicedToday: Boolean?,
        val xpToday: Int?,
        val dailyGoalXp: Int?,
    )
}
