package com.gjuha.core

import java.time.Clock
import java.time.LocalDate
import java.time.ZoneId

/**
 * The learner's recall outcome for a single reviewed word.
 *
 * Mapped from [AnswerGrade] at the call site: correct to [GOOD], near miss to
 * [HARD], incorrect to [AGAIN]. [EASY] is modelled so a future "I knew it
 * instantly" affordance can use it; nothing fabricates it from timing or combo.
 */
enum class ReviewGrade { AGAIN, HARD, GOOD, EASY }

/**
 * Durable scheduling state for one vocabulary word, keyed by the stable word id.
 *
 * Dates are [LocalDate], not instants. The iOS version reduces every date to the
 * start of day in the learner's calendar, because the cadence is once a day;
 * modelling that as a date rather than a timestamp makes the same intent
 * explicit here and removes a whole class of timezone bug.
 */
data class ReviewItemState(
    val wordId: String,
    /** Current spacing interval in days. 0 means due again today. */
    val intervalDays: Int,
    /** SM-2 ease factor. Higher grows intervals faster. Clamped to 1.3..3.0. */
    val ease: Double,
    /** Consecutive non-AGAIN reviews. Drives the early interval ramp. */
    val reps: Int,
    /** Times the word has lapsed since it was introduced. */
    val lapses: Int,
    val dueDate: LocalDate,
    val lastReviewed: LocalDate? = null,
    val introducedAt: LocalDate,
)

/**
 * A deterministic spaced repetition scheduler derived from SM-2 (Wozniak, 1987),
 * ported from the iOS `ReviewScheduler`.
 *
 * Why SM-2 and not FSRS, unchanged from the iOS note: SM-2 is simple, well
 * understood and fully deterministic, so it is unit testable with a fixed clock
 * and needs no per-learner training data. FSRS gives better intervals but fits a
 * machine-learned forgetting curve over a large personal history, which is not
 * deterministic and is premature at launch.
 *
 * Algorithm, at day granularity:
 * - A newly learned word counts the lesson as one successful rep, first spaced
 *   review one day later.
 * - GOOD: 1 day, then 6 days, then previous interval times ease.
 * - EASY: a longer step than GOOD, plus a small ease increase.
 * - HARD: a short step (previous times 1.2), plus a small ease decrease.
 * - AGAIN: a lapse. Ease decreases, the item is due again the same day, and the
 *   rep streak resets so the word has to climb back.
 *
 * Intervals are capped so a word always returns within a year.
 */
class ReviewScheduler(private val zone: ZoneId = ZoneId.systemDefault()) {

    companion object {
        const val DEFAULT_EASE = 2.5
        const val MIN_EASE = 1.3
        const val MAX_EASE = 3.0

        /** Longest spacing allowed, so even easy words resurface within a year. */
        const val MAX_INTERVAL_DAYS = 365

        /**
         * A word counts as mastered once it survives to this interval. Twenty-one
         * days is a conventional long-term retention threshold, roughly three
         * good reviews past the six-day step. Documented because the Profile
         * screen presents it as mastery and nothing else is allowed to.
         */
        const val MASTERY_INTERVAL_DAYS = 21
    }

    fun today(clock: Clock = Clock.system(zone)): LocalDate = LocalDate.now(clock)

    private fun clampEase(value: Double): Double = value.coerceIn(MIN_EASE, MAX_EASE)

    /**
     * State for a word just learned in a lesson. The lesson is the first
     * successful exposure, so the first spaced review is one day later.
     */
    fun newItem(wordId: String, today: LocalDate): ReviewItemState = ReviewItemState(
        wordId = wordId,
        intervalDays = 1,
        ease = DEFAULT_EASE,
        reps = 1,
        lapses = 0,
        dueDate = today.plusDays(1),
        lastReviewed = null,
        introducedAt = today,
    )

    /** Applies a review outcome and returns the updated state. */
    fun apply(grade: ReviewGrade, item: ReviewItemState, today: LocalDate): ReviewItemState =
        when (grade) {
            ReviewGrade.AGAIN -> item.copy(
                lapses = item.lapses + 1,
                reps = 0,
                ease = clampEase(item.ease - 0.20),
                intervalDays = 0,
                dueDate = today, // see it again today
                lastReviewed = today,
            )

            ReviewGrade.HARD -> {
                val base = maxOf(1, item.intervalDays)
                val interval = minOf(MAX_INTERVAL_DAYS, Math.round(base * 1.2).toInt())
                item.copy(
                    ease = clampEase(item.ease - 0.15),
                    intervalDays = interval,
                    reps = item.reps + 1,
                    dueDate = today.plusDays(interval.toLong()),
                    lastReviewed = today,
                )
            }

            ReviewGrade.GOOD -> {
                val raw = when (item.reps) {
                    0 -> 1
                    1 -> 6
                    else -> Math.round(item.intervalDays * item.ease).toInt()
                }
                val interval = minOf(MAX_INTERVAL_DAYS, maxOf(1, raw))
                item.copy(
                    intervalDays = interval,
                    reps = item.reps + 1,
                    dueDate = today.plusDays(interval.toLong()),
                    lastReviewed = today,
                )
            }

            ReviewGrade.EASY -> {
                val ease = clampEase(item.ease + 0.15)
                val raw = when (item.reps) {
                    0 -> 4
                    1 -> 8
                    else -> Math.round(item.intervalDays * ease * 1.3).toInt()
                }
                val interval = minOf(MAX_INTERVAL_DAYS, maxOf(1, raw))
                item.copy(
                    ease = ease,
                    intervalDays = interval,
                    reps = item.reps + 1,
                    dueDate = today.plusDays(interval.toLong()),
                    lastReviewed = today,
                )
            }
        }

    /** Whether the item is due on or before the given day. */
    fun isDue(item: ReviewItemState, today: LocalDate): Boolean = !item.dueDate.isAfter(today)

    /** Whether the item has reached the documented mastery interval. */
    fun isMastered(item: ReviewItemState): Boolean = item.intervalDays >= MASTERY_INTERVAL_DAYS

    /**
     * Due items, struggling words first, in a deterministic order.
     *
     * Earliest due first, then more lapses first so shakier words get priority,
     * then by word id so the order never depends on map iteration.
     */
    fun dueItems(
        items: List<ReviewItemState>,
        today: LocalDate,
        limit: Int? = null,
    ): List<ReviewItemState> {
        val due = items
            .filter { isDue(it, today) }
            .sortedWith(
                compareBy<ReviewItemState> { it.dueDate }
                    .thenByDescending { it.lapses }
                    .thenBy { it.wordId }
            )
        return if (limit != null && limit >= 0) due.take(limit) else due
    }
}
