package com.gjuha.core

/**
 * A milestone the learner can reach, derived from figures they already have.
 * Ported from iOS `Achievement`, including the three rules it holds itself to:
 *
 * 1. Nothing is awarded for opening the app. Every milestone is anchored to real
 *    work: lessons finished, XP earned, days kept, words seen, words retained.
 * 2. Mastery milestones use the honest mastery figure, the one that counts only
 *    words that reached the scheduler's documented long-term interval. "100
 *    words kept" therefore means that, not "100 words seen once".
 * 3. Evaluation is pure: no clock, no randomness, no I/O, so the same stats
 *    always unlock the same set.
 */
data class Achievement(
    /**
     * Stable identifier, persisted in the unlock ledger. It must never change
     * for an existing milestone: renaming one relocks it for every learner who
     * already earned it. These ids match the iOS catalogue exactly so a future
     * sync cannot disagree about what someone has earned.
     */
    val id: String,
    val title: String,
    val detail: String,
    val metric: Metric,
    val threshold: Int,
) {
    /** What a milestone is measured against. Each names a field of [UserStats]. */
    enum class Metric {
        STREAK_DAYS, LESSONS_COMPLETED, TOTAL_XP, WORDS_SEEN, WORDS_MASTERED;

        fun valueIn(stats: UserStats): Int = when (this) {
            STREAK_DAYS -> stats.currentStreak
            LESSONS_COMPLETED -> stats.lessonsCompleted
            TOTAL_XP -> stats.totalXp
            WORDS_SEEN -> stats.wordsSeen
            WORDS_MASTERED -> stats.wordsMastered
        }
    }

    fun isUnlockedBy(stats: UserStats): Boolean = metric.valueIn(stats) >= threshold

    fun progressIn(stats: UserStats): Double =
        if (threshold <= 0) 1.0 else minOf(1.0, metric.valueIn(stats).toDouble() / threshold)

    /** The learner's figure, capped so a label reads "7/7" rather than "12/7". */
    fun progressValueIn(stats: UserStats): Int = minOf(metric.valueIn(stats), threshold)
}

object AchievementCatalog {

    /** Every milestone, in the order they are shown. Ids match iOS exactly. */
    val all: List<Achievement> = listOf(
        Achievement("streak.3", "Three in a row", "Study three days in a row.", Achievement.Metric.STREAK_DAYS, 3),
        Achievement("streak.7", "A full week", "Study seven days in a row.", Achievement.Metric.STREAK_DAYS, 7),
        Achievement("streak.30", "A month of Albanian", "Study thirty days in a row.", Achievement.Metric.STREAK_DAYS, 30),
        Achievement("streak.100", "One hundred days", "Study one hundred days in a row.", Achievement.Metric.STREAK_DAYS, 100),
        Achievement("lessons.1", "First steps", "Finish your first lesson.", Achievement.Metric.LESSONS_COMPLETED, 1),
        Achievement("lessons.10", "Ten lessons in", "Finish ten lessons.", Achievement.Metric.LESSONS_COMPLETED, 10),
        Achievement("lessons.50", "Halfway to fluent", "Finish fifty lessons.", Achievement.Metric.LESSONS_COMPLETED, 50),
        Achievement("xp.500", "Five hundred XP", "Earn 500 XP in total.", Achievement.Metric.TOTAL_XP, 500),
        Achievement("xp.2500", "Serious effort", "Earn 2,500 XP in total.", Achievement.Metric.TOTAL_XP, 2_500),
        Achievement("seen.100", "A hundred words", "Meet 100 different Albanian words.", Achievement.Metric.WORDS_SEEN, 100),
        Achievement("mastered.25", "Twenty-five kept", "Carry 25 words to the long-term review interval.", Achievement.Metric.WORDS_MASTERED, 25),
        Achievement("mastered.100", "One hundred kept", "Carry 100 words to the long-term review interval.", Achievement.Metric.WORDS_MASTERED, 100),
    )

    fun achievement(id: String): Achievement? = all.firstOrNull { it.id == id }

    fun unlockedBy(stats: UserStats): List<Achievement> = all.filter { it.isUnlockedBy(stats) }

    /**
     * The closest milestone not yet reached, by proportion of the way there.
     *
     * Milestones with no progress are still eligible: early on nothing has any,
     * and returning null there would empty the "next up" row exactly when it is
     * most useful. Ties break on id so two equally distant milestones never swap
     * places between launches.
     */
    fun nextUp(stats: UserStats): Achievement? =
        all.filterNot { it.isUnlockedBy(stats) }
            .maxWithOrNull(
                compareBy<Achievement> { it.progressIn(stats) }.thenByDescending { it.id }
            )
}
