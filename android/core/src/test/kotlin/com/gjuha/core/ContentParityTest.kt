package com.gjuha.core

import java.io.File
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertTrue

/**
 * The Android build reads the same seed the iOS app ships, so these assert the
 * figures `Scripts/validate_seed.py` reports. If someone edits the seed and only
 * one platform's checks run, this is what notices.
 */
class ContentParityTest {

    private val seedDir = File("../../Gjuha/Data/Seed")

    private fun read(path: String): String {
        val file = File(seedDir, path)
        assertTrue(file.exists(), "seed file missing: ${file.canonicalPath}")
        return file.readText()
    }

    private val words by lazy { SeedContent.words(read("Vocabulary/a1_vocabulary.json")) }
    private val lessons by lazy { SeedContent.lessons(read("lessons.json")) }
    private val units by lazy { SeedContent.units(read("units.json")) }

    /** The exact counts the iOS seed validator prints. */
    @Test
    fun `the seed has the documented size`() {
        assertEquals(354, words.size, "vocabulary entries")
        assertEquals(120, lessons.size, "lessons")
        assertEquals(12, units.size, "units")
    }

    @Test
    fun `every word has the fields the engine needs`() {
        for (w in words) {
            assertTrue(w.id.isNotBlank(), "a word has no id")
            assertTrue(w.albanian.isNotBlank(), "${w.id} has no Albanian")
            assertTrue(w.english.isNotBlank(), "${w.id} has no English")
            assertTrue(w.cefrLevel.isNotBlank(), "${w.id} has no CEFR level")
        }
    }

    @Test
    fun `word ids are unique`() {
        val ids = words.map { it.id }
        assertEquals(ids.size, ids.toSet().size, "duplicate word id in the seed")
    }

    /** The vocabulary really is an A1 foundation, as the site claims. */
    @Test
    fun `the shipped vocabulary is overwhelmingly a1`() {
        val byLevel = words.groupingBy { it.cefrLevel.lowercase() }.eachCount()
        assertEquals(341, byLevel["a1"], "A1 entries")
        assertEquals(13, byLevel["a2"], "A2 entries")
    }

    @Test
    fun `every lesson belongs to a unit that exists`() {
        val unitNumbers = units.map { it.unit }.toSet()
        for (lesson in lessons) {
            assertTrue(
                lesson.unit in unitNumbers,
                "${'$'}{lesson.id} points at unknown unit ${'$'}{lesson.unit}",
            )
        }
    }

    /** Unlock chains must resolve, or a lesson is unreachable forever. */
    @Test
    fun `every unlock requirement names a lesson that exists`() {
        val ids = lessons.map { it.id }.toSet()
        for (lesson in lessons) {
            for (required in lesson.unlock.requiresLessonIds) {
                assertTrue(
                    required in ids,
                    "${'$'}{lesson.id} requires unknown lesson ${'$'}required",
                )
            }
        }
    }

    @Test
    fun `lesson ids are unique and every lesson has an exercise plan`() {
        val ids = lessons.map { it.id }
        assertEquals(ids.size, ids.toSet().size, "duplicate lesson id")
        for (lesson in lessons) {
            assertTrue(lesson.exercisePlan.isNotEmpty(), "${lesson.id} has no exercise plan")
        }
    }

    /**
     * The plan tokens the Android engine will have to understand. Asserted so a
     * new token added on the iOS side fails here rather than silently producing
     * a lesson with no exercises on Android.
     */
    @Test
    fun `exercise plans use only known tokens`() {
        val known = setOf("mcq", "match", "word_order", "typing", "listening", "cloze")
        val used = lessons.flatMap { it.exercisePlan }.toSet()
        assertTrue(
            used.all { it in known },
            "unknown exercise plan tokens: ${used - known}",
        )
    }

    @Test
    fun `every lesson maps to vocabulary and the mapping is stable`() {
        for (lesson in lessons) {
            val ids = LessonVocabulary.wordIds(lesson, words)
            assertTrue(ids.isNotEmpty(), "${lesson.id} maps to no words")
            assertEquals(ids, LessonVocabulary.wordIds(lesson, words), "mapping is not stable")
            assertTrue(ids.all { id -> words.any { it.id == id } }, "${lesson.id} maps to unknown ids")
        }
    }
}
