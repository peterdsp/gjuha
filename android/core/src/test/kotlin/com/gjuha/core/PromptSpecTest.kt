package com.gjuha.core

import java.io.File
import kotlin.random.Random
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertNotNull
import kotlin.test.assertTrue

/**
 * Whether a question can be asked in a language other than English.
 *
 * A prompt built by interpolation cannot be translated, because the sentence is
 * welded to the word it is about. The engine carries the shape and the subject
 * alongside the English so the interface can rebuild the question.
 */
class PromptSpecTest {

    private val words: List<SeedWord> by lazy {
        SeedContent.words(
            File("../../Gjuha/Data/Seed/Vocabulary/a1_vocabulary.json").readText()
        )
    }
    private val lessons: List<SeedLesson> by lazy {
        SeedContent.lessons(File("../../Gjuha/Data/Seed/lessons.json").readText())
    }

    private fun engine() = ExerciseEngine(words, Random(99))

    @Test
    fun `every exercise in every lesson can be asked in another language`() {
        val engine = engine()
        for (lesson in lessons) {
            val lessonWords = LessonVocabulary.wordIds(lesson, words)
                .mapNotNull { id -> words.firstOrNull { it.id == id } }
            for (exercise in engine.exercises(lesson, lessonWords)) {
                assertNotNull(
                    exercise.promptSpec,
                    "${lesson.id}: a ${exercise.type} question has no translatable form",
                )
            }
        }
    }

    /**
     * The subject is the material being taught, so it is never translated. A
     * question about "mirëdita" must still be about "mirëdita" in Albanian.
     */
    @Test
    fun `the subject of a question is carried untranslated`() {
        val word = words.first { it.albanian == "mirëdita" }
        val mcq = engine().mcqAlbanianToEnglish(word)
        assertEquals(PromptSpec.Kind.MEANING_OF, mcq.promptSpec?.kind)
        assertEquals("mirëdita", mcq.promptSpec?.argument)
    }

    @Test
    fun `the two typing directions are told apart`() {
        val engine = engine()
        val kinds = words.take(40).map { engine.translateTextInput(it).promptSpec?.kind }.toSet()
        assertTrue(
            PromptSpec.Kind.TRANSLATE_TO_ALBANIAN in kinds &&
                PromptSpec.Kind.TRANSLATE_TO_ENGLISH in kinds,
            "both directions should occur, got $kinds",
        )
    }

    /** The blanked sentence is the question, so it is what gets carried. */
    @Test
    fun `a fill in the blank carries the blanked sentence`() {
        val usable = words.first {
            !it.exampleSentence.isNullOrBlank() &&
                !it.exampleTranslation.isNullOrBlank() &&
                it.exampleSentence!!.contains(it.albanian, ignoreCase = true)
        }
        val spec = engine().fillInBlank(usable)?.promptSpec
        assertEquals(PromptSpec.Kind.FILL_THE_BLANK, spec?.kind)
        assertTrue(spec?.argument?.contains("___") == true)
    }

    /**
     * The blank-filling question shows the gapped sentence AND what it means.
     * Carrying only the sentence would leave it unanswerable, which is what a
     * first attempt at this did.
     */
    @Test
    fun `a fill in the blank carries both the sentence and its meaning`() {
        val usable = words.first {
            !it.exampleSentence.isNullOrBlank() &&
                !it.exampleTranslation.isNullOrBlank() &&
                it.exampleSentence!!.contains(it.albanian, ignoreCase = true)
        }
        val exercise = engine().fillInBlank(usable)
        val spec = assertNotNull(exercise?.promptSpec)
        assertTrue(spec.argument.contains("___"))
        assertEquals(usable.exampleTranslation, spec.secondary)
        // Nothing the English prompt said may be lost.
        assertTrue(exercise!!.prompt.contains(spec.secondary))
    }

    /** A question with no subject carries none, rather than an empty one. */
    @Test
    fun `matching needs no subject`() {
        val match = engine().wordMatch(words.take(8))
        assertEquals(PromptSpec.Kind.MATCH_PAIRS, match?.promptSpec?.kind)
        assertEquals("", match?.promptSpec?.argument)
    }

    /** The spec must survive being stored with a resumable session. */
    @Test
    fun `a prompt spec survives a session round trip`() {
        val lesson = lessons.first()
        val lessonWords = LessonVocabulary.wordIds(lesson, words)
            .mapNotNull { id -> words.firstOrNull { it.id == id } }
        val exercises = engine().exercises(lesson, lessonWords)

        val snapshot = LessonSessionSnapshot(
            lessonId = lesson.id,
            exercises = exercises,
            currentIndex = 0,
            hearts = 3,
            xpEarned = 0,
            combo = 0,
            bestCombo = 0,
            answeredCount = 0,
            correctCount = 0,
        )
        val restored = LessonSessionSnapshot.decode(LessonSessionSnapshot.encode(snapshot))
        assertNotNull(restored)
        assertEquals(
            exercises.map { it.promptSpec },
            restored.exercises.map { it.promptSpec },
        )
    }
}
