package com.gjuha.core

import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable
import kotlinx.serialization.json.Json

/**
 * The bundled course content.
 *
 * These mirror the iOS decode-only types field for field, because they read the
 * *same JSON files*. The seed under `Gjuha/Data/Seed/` is the single source of
 * truth for both platforms: the Android build copies it into assets rather than
 * keeping a second copy, so a word can never say one thing on iPhone and another
 * on Android. `ContentParityTest` asserts the figures the iOS seed validator
 * reports.
 */
@Serializable
data class SeedWord(
    val id: String,
    val albanian: String,
    val english: String,
    val cefrLevel: String,
    val partOfSpeech: String,
    val gender: String? = null,
    val verbClass: String? = null,
    val exampleSentence: String? = null,
    val exampleTranslation: String? = null,
    val frequency: Int? = null,
)

@Serializable
data class SeedLesson(
    val id: String,
    /** The unit this lesson belongs to, by its `unit` number. */
    val unit: Int,
    val order: Int,
    val title: String,
    val cefr: String,
    val objectives: List<String> = emptyList(),
    @SerialName("exercise_plan") val exercisePlan: List<String> = emptyList(),
    val unlock: SeedUnlock = SeedUnlock(),
)

/** What a lesson needs finished before it opens. */
@Serializable
data class SeedUnlock(
    @SerialName("requires_lesson_ids") val requiresLessonIds: List<String> = emptyList(),
)

@Serializable
data class SeedUnit(
    /** Units are keyed by number in the seed, not by a string id. */
    val unit: Int,
    val title: String,
    val cefr: String,
    val themes: List<String> = emptyList(),
)

/**
 * Parses the seed files.
 *
 * `ignoreUnknownKeys` on purpose: the iOS decoder tolerates fields it does not
 * know, and a stricter Android parser would turn a harmless additive change to
 * the seed into a crash on one platform only.
 */
/**
 * A grammar guide.
 *
 * [conjugationTable] is a grid of rows with the header first, stored as plain
 * strings because the seed carries it that way and because a table that tries
 * to be typed per part of speech stops fitting the next one.
 */
@Serializable
data class SeedGrammar(
    val id: String,
    val title: String,
    val subtitle: String = "",
    val category: String = "",
    val cefrLevel: String = "",
    val explanation: String = "",
    val examples: List<String> = emptyList(),
    val conjugationTable: List<List<String>> = emptyList(),
)

object SeedContent {

    private val json = Json {
        ignoreUnknownKeys = true
        isLenient = false
    }

    fun words(raw: String): List<SeedWord> = json.decodeFromString(raw)

    fun lessons(raw: String): List<SeedLesson> = json.decodeFromString(raw)

    fun units(raw: String): List<SeedUnit> = json.decodeFromString(raw)

    fun grammar(raw: String): List<SeedGrammar> = json.decodeFromString(raw)
}

/**
 * Which vocabulary a lesson teaches.
 *
 * The iOS engine keeps this mapping in code rather than in the seed, so the two
 * platforms would drift the moment either changed. Here it is derived from the
 * seed instead: lessons carry an order and units carry an order, so a lesson's
 * words are the slice of the frequency-ordered vocabulary that belongs to it.
 *
 * This is deliberately *not* claimed to reproduce the iOS mapping. It is a
 * different, simpler rule, and [ContentParityTest] asserts only what is true of
 * both: every lesson gets words, no word is orphaned, and the mapping is stable.
 * Making the two identical means moving the iOS table into the seed, which is
 * the right next step and is recorded as such.
 */
object LessonVocabulary {

    fun wordIds(lesson: SeedLesson, allWords: List<SeedWord>, perLesson: Int = 10): List<String> {
        if (allWords.isEmpty()) return emptyList()
        val ordered = allWords.sortedBy { it.frequency ?: Int.MAX_VALUE }
        val index = (lesson.order - 1).coerceAtLeast(0)
        val start = (index * perLesson) % ordered.size
        return (0 until minOf(perLesson, ordered.size))
            .map { ordered[(start + it) % ordered.size].id }
            .distinct()
    }
}
