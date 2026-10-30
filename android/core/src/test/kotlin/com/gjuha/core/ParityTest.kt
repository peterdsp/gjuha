package com.gjuha.core

import java.time.LocalDate
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertFalse
import kotlin.test.assertNotNull
import kotlin.test.assertNull
import kotlin.test.assertTrue

/**
 * Parity tests: the Android domain must behave exactly as the iOS one.
 *
 * These assert the same facts as the Swift suite, so a divergence shows up as a
 * failing test rather than as two apps quietly disagreeing about Albanian. Where
 * a case came from a Swift test, the expectation is copied rather than
 * re-derived, because re-deriving it here would only prove this file agrees with
 * itself.
 */
class AnswerNormalizerParityTest {

    @Test
    fun `normalizing trims, folds case and collapses whitespace but keeps diacritics`() {
        assertEquals("faleminderit", AnswerNormalizer.normalize("  Faleminderit  "))
        assertEquals("mirëdita", AnswerNormalizer.normalize("MIRËDITA"))
        assertEquals("natën e mirë", AnswerNormalizer.normalize("natën   e\tmirë"))
    }

    /**
     * The same string in decomposed and precomposed Unicode has to compare
     * equal. A learner typing ë on a Mac and on an Android keyboard can produce
     * different bytes for the same letter.
     */
    @Test
    fun `decomposed and precomposed spellings normalize to the same string`() {
        val precomposed = "mirëdita"
        val decomposed = "mirëdita" // e + combining diaeresis
        assertEquals(
            AnswerNormalizer.normalize(precomposed),
            AnswerNormalizer.normalize(decomposed),
        )
    }

    @Test
    fun `lowercasing does not depend on the device locale`() {
        // On a Turkish locale a naive lowercase maps I to a dotless i, which
        // would silently break every answer containing an I.
        assertEquals("i am", AnswerNormalizer.normalize("I AM"))
    }

    @Test
    fun `alternates and parenthetical glosses are both accepted`() {
        val forms = AnswerNormalizer.acceptedForms("good day / hello")
        assertTrue("good day" in forms)
        assertTrue("hello" in forms)

        val verb = AnswerNormalizer.acceptedForms("I am / to be (1st sg)")
        assertTrue("i am" in verb)
        assertTrue("to be (1st sg)" in verb)
        assertTrue("to be" in verb, "the gloss-stripped form must also be accepted")
    }

    /** The rule the whole course rests on: diacritics are required. */
    @Test
    fun `a dropped diacritic is a near miss, never correct`() {
        assertEquals(AnswerGrade.CORRECT, gradeAnswer("mirëdita", "mirëdita"))
        assertEquals(AnswerGrade.NEAR_MISS, gradeAnswer("miredita", "mirëdita"))
        assertEquals(AnswerGrade.NEAR_MISS, gradeAnswer("pershendetje", "përshëndetje"))
    }

    @Test
    fun `a single typo in a long enough word is a near miss`() {
        assertEquals(AnswerGrade.NEAR_MISS, gradeAnswer("faleminderet", "faleminderit"))
    }

    /** A short word has no typo tolerance: one letter is the whole word. */
    @Test
    fun `a short word gets no typo tolerance`() {
        assertEquals(AnswerGrade.INCORRECT, gradeAnswer("jo", "po"))
    }

    @Test
    fun `an unrelated answer is incorrect`() {
        assertEquals(AnswerGrade.INCORRECT, gradeAnswer("goodbye", "thank you"))
    }

    @Test
    fun `the diacritic hint fires only for diacritics`() {
        val hint = AnswerNormalizer.diacriticHint("miredita", "mirëdita")
        assertNotNull(hint)
        assertTrue(hint.contains("mirëdita"), "the hint names the correct spelling")
        assertTrue(hint.contains("ë"), "the hint names the letters that matter")

        assertNull(
            AnswerNormalizer.diacriticHint("faleminderet", "faleminderit"),
            "a plain typo is not a diacritic problem and must not claim to be",
        )
    }

    @Test
    fun `levenshtein matches the reference values`() {
        assertEquals(0, AnswerNormalizer.levenshtein("same", "same"))
        assertEquals(1, AnswerNormalizer.levenshtein("kitten", "kitteh"))
        assertEquals(3, AnswerNormalizer.levenshtein("kitten", "sitting"))
        assertEquals(4, AnswerNormalizer.levenshtein("", "four"))
    }
}

class ReviewSchedulerParityTest {

    private val scheduler = ReviewScheduler()
    private val day0: LocalDate = LocalDate.of(2026, 1, 1)

    private fun newItem() = scheduler.newItem("w001", day0)

    @Test
    fun `a newly learned word is due one day later`() {
        val item = newItem()
        assertEquals(1, item.intervalDays)
        assertEquals(1, item.reps, "the lesson itself counts as the first rep")
        assertEquals(day0.plusDays(1), item.dueDate)
        assertEquals(ReviewScheduler.DEFAULT_EASE, item.ease)
        assertNull(item.lastReviewed)
    }

    /** The documented ramp: 1 day, then 6, then interval times ease. */
    @Test
    fun `good answers follow the one six then ease ramp`() {
        var item = newItem()

        item = scheduler.apply(ReviewGrade.GOOD, item, day0.plusDays(1))
        assertEquals(6, item.intervalDays, "second good review steps to six days")

        item = scheduler.apply(ReviewGrade.GOOD, item, day0.plusDays(7))
        assertEquals(15, item.intervalDays, "6 times the 2.5 default ease, rounded")
    }

    @Test
    fun `again is a lapse that is due again the same day`() {
        var item = newItem()
        item = scheduler.apply(ReviewGrade.GOOD, item, day0.plusDays(1))
        val easeBefore = item.ease

        val lapseDay = day0.plusDays(7)
        item = scheduler.apply(ReviewGrade.AGAIN, item, lapseDay)

        assertEquals(0, item.intervalDays)
        assertEquals(lapseDay, item.dueDate, "a lapsed word returns the same day")
        assertEquals(0, item.reps, "the rep streak resets so the word climbs back")
        assertEquals(1, item.lapses)
        assertTrue(item.ease < easeBefore, "a lapse lowers ease")
    }

    @Test
    fun `hard takes a short step and lowers ease`() {
        var item = newItem()
        item = scheduler.apply(ReviewGrade.GOOD, item, day0.plusDays(1)) // interval 6
        val easeBefore = item.ease

        item = scheduler.apply(ReviewGrade.HARD, item, day0.plusDays(7))

        assertEquals(7, item.intervalDays, "6 times 1.2, rounded")
        assertTrue(item.ease < easeBefore)
    }

    @Test
    fun `ease never leaves its documented bounds`() {
        var item = newItem()
        repeat(30) { item = scheduler.apply(ReviewGrade.AGAIN, item, day0) }
        assertEquals(ReviewScheduler.MIN_EASE, item.ease)

        var easy = newItem()
        repeat(30) { easy = scheduler.apply(ReviewGrade.EASY, easy, day0) }
        assertEquals(ReviewScheduler.MAX_EASE, easy.ease)
    }

    @Test
    fun `an interval never exceeds a year`() {
        var item = newItem()
        repeat(40) { item = scheduler.apply(ReviewGrade.EASY, item, item.dueDate) }
        assertTrue(
            item.intervalDays <= ReviewScheduler.MAX_INTERVAL_DAYS,
            "every word must resurface within a year, found ${item.intervalDays}",
        )
    }

    /** Mastery is a documented threshold, and nothing else may claim it. */
    @Test
    fun `mastery is exactly the documented interval`() {
        val below = newItem().copy(intervalDays = ReviewScheduler.MASTERY_INTERVAL_DAYS - 1)
        val at = newItem().copy(intervalDays = ReviewScheduler.MASTERY_INTERVAL_DAYS)

        assertFalse(scheduler.isMastered(below))
        assertTrue(scheduler.isMastered(at))
        assertEquals(21, ReviewScheduler.MASTERY_INTERVAL_DAYS)
    }

    @Test
    fun `due selection puts the shakiest words first and is deterministic`() {
        val base = newItem()
        val items = listOf(
            base.copy(wordId = "w003", dueDate = day0, lapses = 0),
            base.copy(wordId = "w001", dueDate = day0, lapses = 2),
            base.copy(wordId = "w002", dueDate = day0, lapses = 2),
            base.copy(wordId = "w004", dueDate = day0.minusDays(3), lapses = 0),
            base.copy(wordId = "w005", dueDate = day0.plusDays(5), lapses = 9),
        )

        val due = scheduler.dueItems(items, day0).map { it.wordId }

        assertEquals(listOf("w004", "w001", "w002", "w003"), due)
        assertTrue("w005" !in due, "a word due in the future is not due now")
        assertEquals(due, scheduler.dueItems(items, day0).map { it.wordId }, "order is stable")
    }

    @Test
    fun `the due limit is respected`() {
        val base = newItem()
        val items = (1..10).map { base.copy(wordId = "w%03d".format(it), dueDate = day0) }
        assertEquals(3, scheduler.dueItems(items, day0, limit = 3).size)
        assertEquals(10, scheduler.dueItems(items, day0, limit = null).size)
    }
}
