package com.gjuha.core

import java.time.LocalDate
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertNotNull
import kotlin.test.assertNull

/** Storing the review schedule. */
class ReviewItemCodecTest {

    private val introduced = LocalDate.of(2026, 10, 1)
    private val due = LocalDate.of(2026, 10, 30)

    private fun item(lastReviewed: LocalDate? = LocalDate.of(2026, 10, 23)) = ReviewItemState(
        wordId = "w042",
        intervalDays = 7,
        ease = 2.35,
        reps = 4,
        lapses = 1,
        dueDate = due,
        lastReviewed = lastReviewed,
        introducedAt = introduced,
    )

    /**
     * Every field, including the one the first version dropped. A scheduler
     * reading a field that silently became null would reschedule wrongly and
     * nothing would report it.
     */
    @Test
    fun `an item survives a round trip with every field intact`() {
        val restored = ReviewItemCodec.decode(ReviewItemCodec.encode(item()))
        assertEquals(item(), restored)
        assertNotNull(restored)
        assertEquals(LocalDate.of(2026, 10, 23), restored.lastReviewed)
    }

    @Test
    fun `a word never reviewed round trips as never reviewed`() {
        val restored = ReviewItemCodec.decode(ReviewItemCodec.encode(item(lastReviewed = null)))
        assertEquals(item(lastReviewed = null), restored)
        assertNull(restored?.lastReviewed)
    }

    /**
     * Rows already on a learner's device were written without the eighth
     * field. They must still load, or upgrading the app would silently wipe
     * the review schedule, which is the most expensive state the app holds.
     */
    @Test
    fun `a row written by the previous format still loads`() {
        val legacy = "w042|7|2.35|4|1|2026-10-30|2026-10-01"
        val restored = ReviewItemCodec.decode(legacy)
        assertNotNull(restored, "an existing learner's schedule must survive the upgrade")
        assertEquals("w042", restored.wordId)
        assertEquals(7, restored.intervalDays)
        assertEquals(due, restored.dueDate)
        assertEquals(introduced, restored.introducedAt)
        assertNull(restored.lastReviewed, "the old format did not carry it")
    }

    @Test
    fun `an unreadable row is skipped rather than throwing`() {
        assertNull(ReviewItemCodec.decode(""))
        assertNull(ReviewItemCodec.decode("w042|7"))
        assertNull(ReviewItemCodec.decode("w042|seven|2.35|4|1|2026-10-30|2026-10-01|-"))
        assertNull(ReviewItemCodec.decode("w042|7|2.35|4|1|not-a-date|2026-10-01|-"))
        assertNull(ReviewItemCodec.decode("|7|2.35|4|1|2026-10-30|2026-10-01|-"))
    }

    /** One bad row costs one word, not the whole schedule. */
    @Test
    fun `a corrupt row does not take the rest of the schedule with it`() {
        val rows = setOf(
            ReviewItemCodec.encode(item()),
            "garbage",
            ReviewItemCodec.encode(item().copy(wordId = "w043")),
        )
        val decoded = ReviewItemCodec.decodeAll(rows)
        assertEquals(2, decoded.size)
        assertEquals(setOf("w042", "w043"), decoded.map { it.wordId }.toSet())
    }

    @Test
    fun `encoding a list keeps one row per word`() {
        val encoded = ReviewItemCodec.encodeAll(
            listOf(item(), item().copy(wordId = "w043"), item().copy(wordId = "w044"))
        )
        assertEquals(3, encoded.size)
    }
}
