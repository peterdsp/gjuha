package com.gjuha.app

import androidx.annotation.StringRes
import com.gjuha.core.Achievement

/**
 * Localized names for the achievement catalogue.
 *
 * The catalogue lives in the shared core, which has no access to Android
 * resources, so its English text is a fallback rather than what is shown. The
 * lookup is keyed on the achievement id because that is the stable thing: the
 * id is persisted in the unlock ledger and must never change, while the wording
 * can be revised in either language.
 *
 * An id with no mapping falls back to the core's English rather than showing
 * nothing, so adding a milestone cannot blank a row.
 */
object AchievementStrings {

    @StringRes
    private fun titleRes(id: String): Int? = when (id) {
        "streak.3" -> R.string.ach_streak_3_title
        "streak.7" -> R.string.ach_streak_7_title
        "streak.30" -> R.string.ach_streak_30_title
        "streak.100" -> R.string.ach_streak_100_title
        "lessons.1" -> R.string.ach_lessons_1_title
        "lessons.10" -> R.string.ach_lessons_10_title
        "lessons.50" -> R.string.ach_lessons_50_title
        "xp.500" -> R.string.ach_xp_500_title
        "xp.2500" -> R.string.ach_xp_2500_title
        "seen.100" -> R.string.ach_seen_100_title
        "mastered.25" -> R.string.ach_mastered_25_title
        "mastered.100" -> R.string.ach_mastered_100_title
        else -> null
    }

    @StringRes
    private fun detailRes(id: String): Int? = when (id) {
        "streak.3" -> R.string.ach_streak_3_detail
        "streak.7" -> R.string.ach_streak_7_detail
        "streak.30" -> R.string.ach_streak_30_detail
        "streak.100" -> R.string.ach_streak_100_detail
        "lessons.1" -> R.string.ach_lessons_1_detail
        "lessons.10" -> R.string.ach_lessons_10_detail
        "lessons.50" -> R.string.ach_lessons_50_detail
        "xp.500" -> R.string.ach_xp_500_detail
        "xp.2500" -> R.string.ach_xp_2500_detail
        "seen.100" -> R.string.ach_seen_100_detail
        "mastered.25" -> R.string.ach_mastered_25_detail
        "mastered.100" -> R.string.ach_mastered_100_detail
        else -> null
    }

    fun title(achievement: Achievement): Int? = titleRes(achievement.id)

    fun detail(achievement: Achievement): Int? = detailRes(achievement.id)
}
