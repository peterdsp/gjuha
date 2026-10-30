package com.gjuha.app

import android.content.Context
import com.gjuha.core.AchievementCatalog
import com.gjuha.core.DailyXp
import com.gjuha.core.LearningGoal
import com.gjuha.core.LessonVocabulary
import com.gjuha.core.ReviewGrade
import com.gjuha.core.ReviewItemState
import com.gjuha.core.ReviewScheduler
import com.gjuha.core.SeedContent
import com.gjuha.core.SeedLesson
import com.gjuha.core.SeedUnit
import com.gjuha.core.SeedWord
import com.gjuha.core.UserStats
import java.time.LocalDate

/**
 * Reads the bundled course.
 *
 * The files come from `Gjuha/Data/Seed`, copied into assets by the build rather
 * than duplicated in this module, so there is one place to edit a word and the
 * two platforms cannot disagree about it.
 */
class ContentRepository(private val context: Context) {

    private fun asset(name: String): String =
        context.assets.open("seed/$name").bufferedReader().use { it.readText() }

    val words: List<SeedWord> by lazy { SeedContent.words(asset("Vocabulary/a1_vocabulary.json")) }
    val lessons: List<SeedLesson> by lazy { SeedContent.lessons(asset("lessons.json")) }
    val units: List<SeedUnit> by lazy { SeedContent.units(asset("units.json")) }

    fun wordsFor(lesson: SeedLesson): List<SeedWord> =
        LessonVocabulary.wordIds(lesson, words).mapNotNull { id -> words.firstOrNull { it.id == id } }

    /** Lessons of a unit, in their seeded order. */
    fun lessons(unit: SeedUnit): List<SeedLesson> =
        lessons.filter { it.unit == unit.unit }.sortedBy { it.order }
}

/**
 * Everything the learner has done, on this device only.
 *
 * Mirrors the iOS stores, including the parts that are deliberate rather than
 * incidental: the three vocabulary figures stay separate, an achievement unlock
 * is written down once and never recomputed downward, and today's XP is stored
 * with the day it belongs to so the rollover needs no timer.
 */
class ProgressRepository(context: Context) {

    private val prefs = context.getSharedPreferences("gjuha.progress", Context.MODE_PRIVATE)
    private val scheduler = ReviewScheduler()

    private object Keys {
        const val COMPLETED = "completedLessonIds"
        const val TOTAL_XP = "totalXp"
        const val STREAK = "currentStreak"
        const val LAST_ACTIVITY = "lastActivityDate"
        const val XP_TODAY = "xpToday"
        const val XP_TODAY_DAY = "xpTodayDay"
        const val GOAL = "learningGoal"
        const val UNLOCKED = "achievementsUnlocked"
        const val REVIEW = "reviewSchedule"
        const val ONBOARDED = "hasCompletedOnboarding"
    }

    var hasCompletedOnboarding: Boolean
        get() = prefs.getBoolean(Keys.ONBOARDED, false)
        set(value) = prefs.edit().putBoolean(Keys.ONBOARDED, value).apply()

    var goal: LearningGoal
        get() = LearningGoal.fromRawValue(prefs.getString(Keys.GOAL, null))
        set(value) = prefs.edit().putString(Keys.GOAL, value.rawValue).apply()

    val completedLessonIds: Set<String>
        get() = prefs.getStringSet(Keys.COMPLETED, emptySet()).orEmpty()

    private val totalXp: Int get() = prefs.getInt(Keys.TOTAL_XP, 0)

    private val dailyXp: DailyXp
        get() = DailyXp(
            amount = prefs.getInt(Keys.XP_TODAY, 0),
            day = prefs.getString(Keys.XP_TODAY_DAY, null)?.let(LocalDate::parse),
        )

    private val streak: Int get() = prefs.getInt(Keys.STREAK, 0)

    /** Word ids that have entered the review schedule, with their state. */
    private fun reviewItems(): List<ReviewItemState> {
        val raw = prefs.getStringSet(Keys.REVIEW, emptySet()).orEmpty()
        return raw.mapNotNull { encoded ->
            // id|interval|ease|reps|lapses|due|introduced
            val p = encoded.split('|')
            if (p.size != 7) return@mapNotNull null
            runCatching {
                ReviewItemState(
                    wordId = p[0],
                    intervalDays = p[1].toInt(),
                    ease = p[2].toDouble(),
                    reps = p[3].toInt(),
                    lapses = p[4].toInt(),
                    dueDate = LocalDate.parse(p[5]),
                    introducedAt = LocalDate.parse(p[6]),
                )
            }.getOrNull()
        }
    }

    private fun writeReviewItems(items: List<ReviewItemState>) {
        prefs.edit().putStringSet(
            Keys.REVIEW,
            items.map {
                listOf(
                    it.wordId, it.intervalDays, it.ease, it.reps,
                    it.lapses, it.dueDate, it.introducedAt,
                ).joinToString("|")
            }.toSet(),
        ).apply()
    }

    fun dueCount(today: LocalDate = LocalDate.now()): Int = dueWordIds(today).size

    /** Word ids the scheduler says are due, soonest first. */
    fun dueWordIds(today: LocalDate = LocalDate.now()): List<String> =
        scheduler.dueItems(reviewItems(), today).map { it.wordId }

    /**
     * Reschedules one word from how it was answered.
     *
     * Called as the learner answers rather than at the end, so a session
     * abandoned half way still records what it measured. A word is recorded
     * once per session: re-recording it would feed the same recall into the
     * schedule twice.
     */
    fun recordReviewOutcome(
        wordId: String,
        grade: ReviewGrade,
        today: LocalDate = LocalDate.now(),
    ) {
        val items = reviewItems()
        val existing = items.firstOrNull { it.wordId == wordId } ?: return
        val updated = scheduler.apply(grade, existing, today)
        writeReviewItems(items.map { if (it.wordId == wordId) updated else it })
    }

    /**
     * Banks a finished review's XP and counts the day for the streak.
     *
     * Deliberately NOT completeLesson: a review must not mark a course lesson
     * finished or touch unlock state, or practising would walk the learner
     * through the course without teaching it. Its words were already
     * rescheduled as they were answered.
     */
    fun recordReviewActivity(xpEarned: Int, today: LocalDate = LocalDate.now()) {
        val editor = prefs.edit()
        editor.putInt(Keys.TOTAL_XP, totalXp + xpEarned)

        val updated = dailyXp.adding(xpEarned, today)
        editor.putInt(Keys.XP_TODAY, updated.earnedOn(today))
        editor.putString(Keys.XP_TODAY_DAY, today.toString())

        val last = prefs.getString(Keys.LAST_ACTIVITY, null)?.let(LocalDate::parse)
        val newStreak = when {
            last == null -> 1
            last == today -> streak
            last.plusDays(1) == today -> streak + 1
            else -> 1
        }
        editor.putInt(Keys.STREAK, newStreak)
        editor.putString(Keys.LAST_ACTIVITY, today.toString())
        editor.apply()
    }

    fun stats(today: LocalDate = LocalDate.now()): UserStats {
        val items = reviewItems()
        return UserStats(
            currentStreak = streak,
            totalXp = totalXp,
            // Exposure: the distinct words the finished lessons covered.
            wordsSeen = wordsSeen(),
            lessonsCompleted = completedLessonIds.size,
            // In the schedule, which is not the same as retained.
            wordsPracticed = items.size,
            // The only figure presented as mastery.
            wordsMastered = items.count { scheduler.isMastered(it) },
            xpToday = dailyXp.earnedOn(today),
            dailyGoalXp = goal.dailyXpGoal,
        )
    }

    private fun wordsSeen(): Int = prefs.getStringSet("wordsSeen", emptySet()).orEmpty().size

    /**
     * Records a finished lesson: banks its XP once, counts the day for the
     * streak, and puts its new words into the review schedule without
     * disturbing any that are already there.
     */
    fun completeLesson(
        lessonId: String,
        xpEarned: Int,
        wordIds: List<String>,
        today: LocalDate = LocalDate.now(),
    ) {
        val editor = prefs.edit()
        editor.putStringSet(Keys.COMPLETED, completedLessonIds + lessonId)
        editor.putInt(Keys.TOTAL_XP, totalXp + xpEarned)

        val updated = dailyXp.adding(xpEarned, today)
        editor.putInt(Keys.XP_TODAY, updated.earnedOn(today))
        editor.putString(Keys.XP_TODAY_DAY, today.toString())

        editor.putStringSet(
            "wordsSeen",
            prefs.getStringSet("wordsSeen", emptySet()).orEmpty() + wordIds,
        )

        // Streak: same rule as iOS. Same day does nothing, the next day
        // advances, a gap restarts at one.
        val last = prefs.getString(Keys.LAST_ACTIVITY, null)?.let(LocalDate::parse)
        val newStreak = when {
            last == null -> 1
            last == today -> streak
            last.plusDays(1) == today -> streak + 1
            else -> 1
        }
        editor.putInt(Keys.STREAK, newStreak)
        editor.putString(Keys.LAST_ACTIVITY, today.toString())
        editor.apply()

        // Words already scheduled keep their progress; only new ones are added.
        val existing = reviewItems()
        val known = existing.map { it.wordId }.toSet()
        writeReviewItems(existing + wordIds.filterNot { it in known }.map { scheduler.newItem(it, today) })
    }

    /**
     * Records any milestone the current stats have earned and returns those
     * newly recorded. The ledger is only ever added to: a streak can break, and
     * a month the learner actually studied is a fact, not a current state.
     */
    fun recordUnlocks(today: LocalDate = LocalDate.now()): List<String> {
        val already = prefs.getStringSet(Keys.UNLOCKED, emptySet()).orEmpty()
        val earned = AchievementCatalog.unlockedBy(stats(today)).map { it.id }.toSet()
        val fresh = earned - already
        if (fresh.isNotEmpty()) {
            prefs.edit().putStringSet(Keys.UNLOCKED, already + fresh).apply()
        }
        return fresh.toList()
    }

    /** Unlocked ids, filtered to ones this build still defines. */
    fun unlockedAchievementIds(): Set<String> =
        prefs.getStringSet(Keys.UNLOCKED, emptySet()).orEmpty()
            .filter { AchievementCatalog.achievement(it) != null }
            .toSet()

    fun reset() = prefs.edit().clear().apply()
}
