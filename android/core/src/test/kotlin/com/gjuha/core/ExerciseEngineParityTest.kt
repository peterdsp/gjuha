package com.gjuha.core

import java.io.File
import kotlin.random.Random
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertFalse
import kotlin.test.assertNotNull
import kotlin.test.assertNull
import kotlin.test.assertTrue

/**
 * The exercise engine, held to the rules the iOS version documents as promises
 * rather than implementation details.
 *
 * Runs against the real shipped seed, not fixtures, so a content change that
 * would make a question unanswerable fails here.
 */
class ExerciseEngineParityTest {

    private val seedDir = File("../../Gjuha/Data/Seed")

    private val words: List<SeedWord> by lazy {
        SeedContent.words(File(seedDir, "Vocabulary/a1_vocabulary.json").readText())
    }
    private val lessons: List<SeedLesson> by lazy {
        SeedContent.lessons(File(seedDir, "lessons.json").readText())
    }

    /** Fixed seed so a failure is reproducible rather than occasional. */
    private fun engine(withAudio: Set<String> = emptySet()) =
        ExerciseEngine(words, Random(20261030), withAudio)

    private fun word(id: String) = words.first { it.id == id }

    // MARK: Plan mapping

    @Test
    fun `plan tokens map exactly as on iOS`() {
        assertEquals(ExerciseType.MULTIPLE_CHOICE_TRANSLATE, ExerciseType.fromPlanToken("mcq"))
        assertEquals(ExerciseType.WORD_MATCH, ExerciseType.fromPlanToken("match"))
        assertEquals(ExerciseType.ARRANGE_WORDS, ExerciseType.fromPlanToken("word_order"))
        assertEquals(ExerciseType.TRANSLATE_TEXT_INPUT, ExerciseType.fromPlanToken("typing"))
        assertEquals(ExerciseType.TAP_WHAT_YOU_HEAR, ExerciseType.fromPlanToken("listening"))
        assertEquals(ExerciseType.FILL_IN_BLANK, ExerciseType.fromPlanToken("cloze"))
        assertNull(ExerciseType.fromPlanToken("nonsense"))
    }

    @Test
    fun `an unrecognised plan falls back rather than producing nothing`() {
        assertEquals(ExerciseType.defaultPlan, ExerciseType.plannedTypes(listOf("nope", "also-nope")))
        assertEquals(ExerciseType.defaultPlan, ExerciseType.plannedTypes(emptyList()))
    }

    // MARK: Distractors, the rule that makes a question answerable

    /**
     * The promise: an option that would also be correct is never offered. If it
     * were, the question would have two right answers and grading would mark one
     * of them wrong.
     */
    @Test
    fun `no distractor is also a correct answer, for every word in the seed`() {
        val engine = engine()
        for (w in words) {
            for (useEnglish in listOf(true, false)) {
                val answer = if (useEnglish) w.english else w.albanian
                val accepted = AnswerNormalizer.acceptedForms(answer)
                for (d in engine.pickDistractors(w, count = 3, useEnglish = useEnglish)) {
                    val forms = AnswerNormalizer.acceptedForms(d)
                    assertTrue(
                        forms.none { it in accepted },
                        "distractor '$d' is also correct for '${w.albanian}' -> '$answer'",
                    )
                }
            }
        }
    }

    @Test
    fun `distractors are distinct and never the word itself`() {
        val engine = engine()
        for (w in words.take(60)) {
            val picked = engine.pickDistractors(w, count = 3, useEnglish = true)
            assertEquals(picked.size, picked.toSet().size, "duplicate distractor for ${w.id}")
            assertFalse(w.english in picked, "the answer was offered as its own distractor")
        }
    }

    /** Plausibility: a same-part-of-speech pool must be preferred when one exists. */
    @Test
    fun `distractors prefer the same part of speech`() {
        val engine = engine()
        val verb = words.first { it.partOfSpeech == "verb" }
        val picked = engine.pickDistractors(verb, count = 3, useEnglish = false)
        val pickedPos = picked.mapNotNull { text -> words.firstOrNull { it.albanian == text }?.partOfSpeech }
        assertTrue(
            pickedPos.isNotEmpty() && pickedPos.all { it == "verb" },
            "expected verbs, got $pickedPos",
        )
    }

    /** A pool too small to be plausible still has to produce a usable question. */
    @Test
    fun `a tiny pool still yields enough options`() {
        val tiny = listOf(word("w001"))
        val picked = ExerciseEngine(tiny, Random(1)).pickDistractors(
            tiny.first(), pool = tiny, count = 3, useEnglish = true,
        )
        assertEquals(3, picked.size, "the fallback must fill the gap")
    }

    // MARK: Built exercises

    @Test
    fun `multiple choice offers the answer among its options exactly once`() {
        val engine = engine()
        for (w in words.take(40)) {
            val mcq = engine.mcqAlbanianToEnglish(w)
            assertEquals(4, mcq.orderedOptions.size)
            assertEquals(
                1,
                mcq.orderedOptions.count { it == mcq.correctAnswer },
                "the answer must appear exactly once for ${w.id}",
            )
        }
    }

    /** Options are fixed at construction, so the UI cannot make them jump. */
    @Test
    fun `options do not reshuffle when read again`() {
        val mcq = engine().mcqAlbanianToEnglish(word("w001"))
        assertEquals(mcq.orderedOptions, mcq.orderedOptions)
    }

    @Test
    fun `typed translation direction is stable for a given word`() {
        val engine = engine()
        val first = engine.translateTextInput(word("w002"))
        val again = engine.translateTextInput(word("w002"))
        assertEquals(first.prompt, again.prompt)
        assertEquals(first.correctAnswer, again.correctAnswer)
        assertTrue(first.hint == "Type in Albanian" || first.hint == "Type in English")
    }

    @Test
    fun `word order never starts in the answer order`() {
        val engine = engine()
        val withSentences = words.filter { (it.exampleSentence?.split(" ")?.size ?: 0) >= 3 }
        assertTrue(withSentences.isNotEmpty(), "the seed has no usable sentences")
        for (w in withSentences.take(30)) {
            val exercise = engine.arrangeWords(w) ?: continue
            assertFalse(
                exercise.orderedOptions.joinToString(" ") == exercise.correctAnswer,
                "${w.id} was dealt already solved",
            )
            assertEquals(
                exercise.correctAnswer.split(" ").sorted(),
                exercise.orderedOptions.sorted(),
                "${w.id} lost or gained a token when shuffled",
            )
        }
    }

    @Test
    fun `a word with no example sentence cannot build word order`() {
        val bare = words.first { it.exampleSentence.isNullOrBlank() }
        assertNull(engine().arrangeWords(bare))
    }

    @Test
    fun `cloze blanks the word and keeps the translation`() {
        val engine = engine()
        val usable = words.firstOrNull {
            !it.exampleSentence.isNullOrBlank() &&
                !it.exampleTranslation.isNullOrBlank() &&
                it.exampleSentence!!.contains(it.albanian, ignoreCase = true)
        }
        assertNotNull(usable, "the seed has no word usable for a cloze")
        val cloze = engine.fillInBlank(usable)
        assertNotNull(cloze)
        assertTrue(cloze.prompt.contains("___"), "the blank is missing")
        assertEquals(usable.albanian, cloze.correctAnswer)
        assertTrue(cloze.prompt.contains(usable.exampleTranslation!!))
    }

    @Test
    fun `matching pairs are unique on both sides`() {
        val match = engine().wordMatch(words.take(10))
        assertNotNull(match)
        assertEquals(4, match.pairs.size)
        assertEquals(4, match.pairs.map { it.albanian }.toSet().size)
        assertEquals(4, match.pairs.map { it.english }.toSet().size)
    }

    /**
     * The gloss rule: a match tile shows the part before any "/" or "(". This is
     * what the iOS screenshot solver had to learn the hard way.
     */
    @Test
    fun `matching shortens a glossed english to its head`() {
        val glossed = words.first { it.english.contains("/") }
        val match = engine().wordMatch(listOf(glossed) + words.filter { it.id != glossed.id }.take(5))
        assertNotNull(match)
        val pair = match.pairs.firstOrNull { it.albanian == glossed.albanian }
        assertNotNull(pair, "the glossed word was dropped from the pairs")
        assertFalse(pair.english.contains("/"), "the gloss was not shortened: ${pair.english}")
    }

    /** Listening must never be faked while no reviewed audio ships. */
    @Test
    fun `listening is unavailable without reviewed audio and falls back`() {
        assertNull(engine().listening(word("w001")), "no audio ships, so none may be claimed")

        val withAudio = engine(withAudio = setOf("w001"))
        val exercise = withAudio.listening(word("w001"))
        assertNotNull(exercise)
        assertEquals(ExerciseType.TAP_WHAT_YOU_HEAR, exercise.type)
    }

    // MARK: Whole lessons

    @Test
    fun `every lesson in the seed builds answerable exercises`() {
        val engine = engine()
        for (lesson in lessons) {
            val lessonWords = LessonVocabulary.wordIds(lesson, words)
                .mapNotNull { id -> words.firstOrNull { it.id == id } }
            val exercises = engine.exercises(lesson, lessonWords)

            assertTrue(exercises.isNotEmpty(), "${lesson.id} produced no exercises")
            assertTrue(
                exercises.size <= ExerciseEngine.MAX_EXERCISES,
                "${lesson.id} produced ${exercises.size}, over the cap",
            )
            for (e in exercises) {
                assertTrue(e.prompt.isNotBlank(), "${lesson.id} has a blank prompt")
                assertTrue(e.correctAnswer.isNotBlank(), "${lesson.id} has a blank answer")
                assertTrue(e.xpValue > 0, "${lesson.id} has a worthless exercise")
                if (e.orderedOptions.isNotEmpty() && e.type != ExerciseType.ARRANGE_WORDS) {
                    assertTrue(
                        e.correctAnswer in e.orderedOptions,
                        "${lesson.id}: the answer is not among the options",
                    )
                }
            }
        }
    }

    /** No lesson may be all one format when its plan asked for a mix. */
    @Test
    fun `a lesson mixes formats when its plan asks for several`() {
        val engine = engine()
        val lesson = lessons.first { it.exercisePlan.size >= 3 }
        val lessonWords = LessonVocabulary.wordIds(lesson, words)
            .mapNotNull { id -> words.firstOrNull { it.id == id } }
        val types = engine.exercises(lesson, lessonWords).map { it.type }.toSet()
        assertTrue(types.size >= 2, "expected a mix, got $types")
    }

    @Test
    fun `generation is deterministic for a fixed seed`() {
        val lesson = lessons.first()
        val lessonWords = LessonVocabulary.wordIds(lesson, words)
            .mapNotNull { id -> words.firstOrNull { it.id == id } }

        val first = ExerciseEngine(words, Random(7)).exercises(lesson, lessonWords)
        val second = ExerciseEngine(words, Random(7)).exercises(lesson, lessonWords)
        assertEquals(first, second)
    }
}
