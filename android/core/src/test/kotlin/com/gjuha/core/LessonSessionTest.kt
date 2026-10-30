package com.gjuha.core

import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertFalse
import kotlin.test.assertNotNull
import kotlin.test.assertNull
import kotlin.test.assertTrue

/** Resuming a lesson that was interrupted. */
class LessonSessionTest {

    private fun exercise(prompt: String) = Exercise(
        type = ExerciseType.MULTIPLE_CHOICE_TRANSLATE,
        prompt = prompt,
        correctAnswer = "hello",
        xpValue = 10,
        orderedOptions = listOf("hello", "goodbye", "please", "yes"),
    )

    private fun snapshot(
        index: Int = 1,
        hearts: Int = 2,
        isReview: Boolean = false,
    ) = LessonSessionSnapshot(
        lessonId = "u1l1",
        exercises = listOf(exercise("a"), exercise("b"), exercise("c")),
        currentIndex = index,
        hearts = hearts,
        xpEarned = 30,
        combo = 2,
        bestCombo = 4,
        answeredCount = 2,
        correctCount = 1,
        isReview = isReview,
    )

    /**
     * The round trip has to be exact, because the stored exercises ARE the
     * lesson. Regenerating would hand the learner different questions than the
     * ones they were halfway through.
     */
    @Test
    fun `a session survives being written and read back unchanged`() {
        val original = snapshot()
        val restored = LessonSessionSnapshot.decode(LessonSessionSnapshot.encode(original))
        assertEquals(original, restored)
        assertNotNull(restored)
        assertEquals(
            original.exercises.map { it.orderedOptions },
            restored.exercises.map { it.orderedOptions },
            "the option order must survive, or the answers move on resume",
        )
    }

    /** A corrupt or half written value costs one partial lesson, not a crash. */
    @Test
    fun `an unreadable session decodes to nothing rather than throwing`() {
        assertNull(LessonSessionSnapshot.decode(null))
        assertNull(LessonSessionSnapshot.decode(""))
        assertNull(LessonSessionSnapshot.decode("{\"lessonId\":"))
        assertNull(LessonSessionSnapshot.decode("not json at all"))
    }

    @Test
    fun `a session mid lesson is resumable`() {
        assertTrue(snapshot().isResumable)
    }

    @Test
    fun `a finished or failed session is not offered as a resume`() {
        assertFalse(snapshot(index = 3).isResumable, "nothing left to answer")
        assertFalse(snapshot(hearts = 0).isResumable, "the attempt already failed")
        assertFalse(
            snapshot().copy(exercises = emptyList()).isResumable,
            "a session with no exercises is not a lesson",
        )
    }

    /**
     * Reviews reschedule each word as it is answered, so resuming one would
     * re-ask words that have already been recorded and feed the same recall
     * into the schedule twice.
     */
    @Test
    fun `a review is never resumable`() {
        assertFalse(snapshot(isReview = true).isResumable)
    }

    /**
     * The accumulator is for this attempt only. Restoring it must not look like
     * XP that has already been banked.
     */
    @Test
    fun `restoring carries the attempt's xp without banking it`() {
        val restored = LessonSessionSnapshot.decode(LessonSessionSnapshot.encode(snapshot()))
        assertNotNull(restored)
        assertEquals(30, restored.xpEarned, "the attempt's accumulator is carried")
        assertEquals(4, restored.bestCombo, "best combo is kept separately from the live combo")
        assertEquals(2, restored.combo)
    }
}
