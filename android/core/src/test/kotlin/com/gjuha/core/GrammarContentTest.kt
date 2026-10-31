package com.gjuha.core

import java.io.File
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertTrue

/** The grammar guides, read from the file the iOS app ships. */
class GrammarContentTest {

    private val guides: List<SeedGrammar> by lazy {
        SeedContent.grammar(
            File("../../Gjuha/Data/Seed/Grammar/a1_grammar.json").readText()
        )
    }

    @Test
    fun `the shipped grammar file parses`() {
        assertTrue(guides.isNotEmpty(), "no guides were read")
        assertEquals(guides.size, guides.map { it.id }.toSet().size, "duplicate guide id")
    }

    @Test
    fun `every guide is readable rather than a stub`() {
        for (g in guides) {
            assertTrue(g.title.isNotBlank(), "${g.id} has no title")
            assertTrue(g.explanation.isNotBlank(), "${g.id} has no explanation")
            assertTrue(g.examples.isNotEmpty(), "${g.id} shows no examples")
        }
    }

    /**
     * A ragged table renders as a broken grid, and the header row is what names
     * the columns, so both are checked rather than assumed.
     */
    @Test
    fun `a conjugation table is rectangular and has a header`() {
        for (g in guides.filter { it.conjugationTable.isNotEmpty() }) {
            val widths = g.conjugationTable.map { it.size }.toSet()
            assertEquals(1, widths.size, "${g.id} has a ragged table: $widths")
            assertTrue(g.conjugationTable.size >= 2, "${g.id} has a header but no rows")
            // The corner cell of a cross-tabulation is legitimately empty:
            // g003 labels its rows Indefinite/Definite and its columns
            // Masculine/Feminine, so the top-left names nothing. Every other
            // heading has to be named or a column is unreadable.
            assertTrue(
                g.conjugationTable.first().drop(1).all { it.isNotBlank() },
                "${g.id} has a blank column heading",
            )
        }
    }
}
