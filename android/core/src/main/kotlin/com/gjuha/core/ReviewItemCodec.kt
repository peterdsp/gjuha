package com.gjuha.core

import java.time.LocalDate

/**
 * Stores a scheduled word as one line of text.
 *
 * A compact line rather than JSON because these are held in a string set, one
 * row per word, and the set is rewritten on every answer.
 *
 * The first version of this wrote six fields and silently dropped
 * [ReviewItemState.lastReviewed]. Nothing read it, so nothing broke, but a
 * field that is written and then thrown away is a trap for whoever first
 * believes it: review history is exactly what a smarter scheduler would want.
 * It is now carried, and the older rows still load.
 */
object ReviewItemCodec {

    private const val SEPARATOR = '|'
    private const val ABSENT = "-"

    /** Fields in a row written before [lastReviewed] was carried. */
    private const val LEGACY_FIELDS = 7
    private const val FIELDS = 8

    fun encode(item: ReviewItemState): String = listOf(
        item.wordId,
        item.intervalDays.toString(),
        item.ease.toString(),
        item.reps.toString(),
        item.lapses.toString(),
        item.dueDate.toString(),
        item.introducedAt.toString(),
        item.lastReviewed?.toString() ?: ABSENT,
    ).joinToString(SEPARATOR.toString())

    /**
     * Reads a row, returning null rather than throwing.
     *
     * One unreadable row costs one word's schedule. Throwing would cost the
     * whole schedule, and on a launch path, the whole app.
     */
    fun decode(raw: String): ReviewItemState? {
        val parts = raw.split(SEPARATOR)
        if (parts.size != FIELDS && parts.size != LEGACY_FIELDS) return null
        return runCatching {
            ReviewItemState(
                wordId = parts[0].also { require(it.isNotBlank()) },
                intervalDays = parts[1].toInt(),
                ease = parts[2].toDouble(),
                reps = parts[3].toInt(),
                lapses = parts[4].toInt(),
                dueDate = LocalDate.parse(parts[5]),
                introducedAt = LocalDate.parse(parts[6]),
                // A row written by the older format has no eighth field, and a
                // word that has never been reviewed writes the absent marker.
                lastReviewed = parts.getOrNull(7)
                    ?.takeIf { it != ABSENT }
                    ?.let(LocalDate::parse),
            )
        }.getOrNull()
    }

    fun encodeAll(items: List<ReviewItemState>): Set<String> =
        items.map(::encode).toSet()

    fun decodeAll(raw: Set<String>): List<ReviewItemState> = raw.mapNotNull(::decode)
}
