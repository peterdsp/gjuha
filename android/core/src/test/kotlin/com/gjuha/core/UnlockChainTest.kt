package com.gjuha.core

import java.io.File
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertFalse
import kotlin.test.assertTrue

/**
 * Whether the course can actually be walked from beginning to end.
 *
 * The lesson map once showed only the first unit, so ten lessons were
 * reachable and a hundred and ten were not. That was invisible in a
 * screenshot, because one unit fills the screen and looks exactly like a
 * course with more below it. These assert the progression itself rather than
 * what any screen happens to draw.
 */
class UnlockChainTest {

    private val lessons: List<SeedLesson> by lazy {
        SeedContent.lessons(File("../../Gjuha/Data/Seed/lessons.json").readText())
            .sortedWith(compareBy({ it.unit }, { it.order }))
    }

    /** The rule the app uses, stated once here so the test cannot drift from it. */
    private fun isUnlocked(lesson: SeedLesson, completed: Set<String>) =
        lesson.unlock.requiresLessonIds.all { it in completed }

    @Test
    fun `the first lesson is open to a learner who has done nothing`() {
        assertTrue(isUnlocked(lessons.first(), emptySet()))
    }

    /**
     * The whole course, one lesson at a time. If any lesson required something
     * that never becomes available, the walk stops short and this reports how
     * far it got.
     */
    @Test
    fun `finishing lessons in order opens every lesson in the course`() {
        val completed = mutableSetOf<String>()
        for (lesson in lessons) {
            assertTrue(
                isUnlocked(lesson, completed),
                "${lesson.id} (unit ${lesson.unit}) is unreachable: it requires " +
                    "${lesson.unlock.requiresLessonIds} but only ${completed.size} " +
                    "lessons come before it",
            )
            completed += lesson.id
        }
        assertEquals(lessons.size, completed.size)
    }

    /**
     * The boundary the map bug hid. Unit 2 must open once unit 1 is finished,
     * with no special handling for crossing between units.
     */
    @Test
    fun `finishing a unit opens the next one`() {
        val byUnit = lessons.groupBy { it.unit }
        val units = byUnit.keys.sorted()
        assertTrue(units.size > 1, "a single unit course cannot test this")

        val completed = mutableSetOf<String>()
        for ((index, unit) in units.withIndex()) {
            val first = byUnit.getValue(unit).first()
            assertTrue(
                isUnlocked(first, completed),
                "unit $unit never opens: its first lesson ${first.id} requires " +
                    "${first.unlock.requiresLessonIds}",
            )
            if (index == 0) {
                assertFalse(
                    isUnlocked(byUnit.getValue(units[1]).first(), emptySet()),
                    "unit 2 should not be open before anything is finished",
                )
            }
            completed += byUnit.getValue(unit).map { it.id }
        }
    }

    /** Nothing may be orphaned behind a requirement that does not exist. */
    @Test
    fun `every requirement names a real lesson that comes earlier`() {
        val seen = mutableSetOf<String>()
        for (lesson in lessons) {
            for (required in lesson.unlock.requiresLessonIds) {
                assertTrue(
                    required in seen,
                    "${lesson.id} requires $required, which is not an earlier lesson",
                )
            }
            seen += lesson.id
        }
    }
}
