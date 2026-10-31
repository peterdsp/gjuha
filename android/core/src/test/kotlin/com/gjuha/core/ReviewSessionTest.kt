package com.gjuha.core

import java.io.File
import java.time.LocalDate
import kotlin.random.Random
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertFalse
import kotlin.test.assertTrue

/**
 * A review session, held to the rules that keep the schedule trustworthy.
 *
 * These are the same rules the iOS LessonFeature enforces in review mode, and
 * they exist because getting them wrong corrupts the spacing silently: the
 * learner sees a normal session and the intervals quietly stop meaning
 * anything.
 */
class ReviewSessionTest {

    private val words: List<SeedWord> by lazy {
        SeedContent.words(
            File("../../Gjuha/Data/Seed/Vocabulary/a1_vocabulary.json").readText()
        )
    }

    private fun engine() = ExerciseEngine(words, Random(4242))

    @Test
    fun `every review exercise names the word it is testing`() {
        val due = words.take(8)
        val session = engine().reviewExercises(due)

        assertTrue(session.isNotEmpty())
        for ((wordId, _) in session) {
            assertTrue(
                words.any { it.id == wordId },
                "a review exercise was tagged with an unknown word id: $wordId",
            )
        }
    }

    /**
     * Matching covers four words in one answer, so a single outcome cannot say
     * which of them was recalled. Including it would reschedule four words from
     * one signal.
     */
    @Test
    fun `review never uses matching`() {
        val session = engine().reviewExercises(words.take(20))
        assertTrue(session.isNotEmpty())
        assertFalse(
            session.any { it.second.type == ExerciseType.WORD_MATCH },
            "matching cannot reschedule a single word",
        )
    }

    @Test
    fun `a review asks about due words only, and never twice about one`() {
        val due = words.take(6)
        val dueIds = due.map { it.id }.toSet()
        val session = engine().reviewExercises(due)

        val asked = session.map { it.first }
        assertTrue(asked.all { it in dueIds }, "a word that was not due was asked about")
        assertEquals(asked.size, asked.toSet().size, "a word was asked about twice")
    }

    @Test
    fun `an empty due list produces no session`() {
        assertTrue(engine().reviewExercises(emptyList()).isEmpty())
    }

    @Test
    fun `a review is capped so it stays a session rather than a slog`() {
        val session = engine().reviewExercises(words, limit = ExerciseEngine.MAX_EXERCISES)
        assertTrue(session.size <= ExerciseEngine.MAX_EXERCISES)
    }

    // MARK: The grade mapping, which must match iOS exactly

    /**
     * correct -> GOOD, near miss -> HARD, wrong -> AGAIN. A near miss is a
     * recalled word with a spelling slip, so it is neither a clean success nor
     * a failure, and collapsing it into either one would misreport recall.
     */
    @Test
    fun `answer grades map to review grades the way iOS maps them`() {
        assertEquals(ReviewGrade.GOOD, AnswerGrade.CORRECT.toReviewGrade())
        assertEquals(ReviewGrade.HARD, AnswerGrade.NEAR_MISS.toReviewGrade())
        assertEquals(ReviewGrade.AGAIN, AnswerGrade.INCORRECT.toReviewGrade())
    }

    /** A near miss must not extend the interval as far as a clean recall. */
    @Test
    fun `a near miss schedules sooner than a clean recall`() {
        val scheduler = ReviewScheduler()
        val today = LocalDate.of(2026, 10, 30)
        val item = scheduler.newItem("w001", today).let {
            scheduler.apply(ReviewGrade.GOOD, it, today)
        }

        val good = scheduler.apply(ReviewGrade.GOOD, item, today)
        val hard = scheduler.apply(ReviewGrade.HARD, item, today)

        assertTrue(
            hard.dueDate < good.dueDate,
            "a near miss (${hard.dueDate}) must come back before a clean recall (${good.dueDate})",
        )
    }

    /** A wrong answer must bring the word back, not push it away. */
    @Test
    fun `a wrong answer resets the word to be seen again soon`() {
        val scheduler = ReviewScheduler()
        val today = LocalDate.of(2026, 10, 30)
        var item = scheduler.newItem("w001", today)
        repeat(4) { item = scheduler.apply(ReviewGrade.GOOD, item, today) }
        assertTrue(item.intervalDays > 1, "the word should be well spaced by now")

        val lapsed = scheduler.apply(ReviewGrade.AGAIN, item, today)
        assertTrue(lapsed.intervalDays <= 1, "a lapse must bring the word straight back")
        assertEquals(item.lapses + 1, lapsed.lapses, "the lapse was not counted")
        assertTrue(lapsed.ease < item.ease, "a lapse must make the word harder, not easier")
    }
}
