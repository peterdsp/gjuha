package com.gjuha.core

import java.text.Normalizer
import java.util.Locale

/**
 * Answer comparison, ported from the iOS `AnswerNormalizer`.
 *
 * This is the first thing to port and the one that most has to match. It decides
 * whether a learner was right, and a difference between the platforms here would
 * not look like a bug: it would look like the app disagreeing with itself about
 * Albanian. `AnswerNormalizerParityTest` holds it to the same cases the Swift
 * tests assert.
 *
 * The rule that matters: Albanian diacritics are required. Dropping an ë or a ç
 * is surfaced as a *near miss* with a pointed hint, never accepted as correct.
 */
object AnswerNormalizer {

    /**
     * Canonical comparison form: NFC Unicode, trimmed, lowercased, with internal
     * runs of whitespace collapsed to a single space. Diacritics are preserved.
     *
     * `Locale.ROOT` for the lowercasing, not the default locale. On a Turkish
     * device the default would map "I" to a dotless "ı" and quietly break
     * comparison for every answer containing an I.
     */
    fun normalize(raw: String): String =
        Normalizer.normalize(raw, Normalizer.Form.NFC)
            .lowercase(Locale.ROOT)
            .split(Regex("\\s+"))
            .filter { it.isNotEmpty() }
            .joinToString(" ")

    /**
     * Every acceptable spelling of a correct answer, normalised.
     *
     * Splits `/` and `;` alternates ("good day / hello") and also offers each
     * alternate with a trailing parenthetical gloss removed, so "to be (1st sg)"
     * also accepts "to be".
     */
    fun acceptedForms(correctAnswer: String): Set<String> {
        val forms = linkedSetOf<String>()
        for (part in correctAnswer.split('/', ';')) {
            val trimmed = part.trim()
            if (trimmed.isEmpty()) continue
            forms += normalize(trimmed)
            stripTrailingParenthetical(trimmed)?.let { forms += normalize(it) }
        }
        return forms
    }

    private fun stripTrailingParenthetical(s: String): String? {
        val open = s.indexOf('(')
        if (open < 0 || !s.contains(')')) return null
        val head = s.substring(0, open).trim()
        return head.ifEmpty { null }
    }

    /**
     * A near miss is a typed answer that differs from an accepted form only by
     * diacritics, or by a single typo in a word long enough for that to be
     * meaningful. It is never accepted as correct.
     */
    fun isNearMiss(normalizedAnswer: String, acceptedForms: Set<String>): Boolean {
        for (form in acceptedForms) {
            if (foldDiacritics(normalizedAnswer) == foldDiacritics(form)) return true
            val threshold = if (form.length >= 5) 1 else 0
            if (threshold > 0 && levenshtein(normalizedAnswer, form) <= threshold) return true
        }
        return false
    }

    /**
     * When a near miss is only a dropped or added Albanian diacritic, returns a
     * hint naming the letters that matter and the correct spelling. Returns null
     * for a plain typo, so the caller only shows this when it really is about
     * ë and ç, tying the feedback to what the learner actually typed.
     */
    fun diacriticHint(submitted: String, correctAnswer: String): String? {
        val normalized = normalize(submitted)
        for (form in acceptedForms(correctAnswer)) {
            if (normalized != form && foldDiacritics(normalized) == foldDiacritics(form)) {
                return "Mind the Albanian letters ë and ç: the correct spelling is \"$form\"."
            }
        }
        return null
    }

    /**
     * Folds diacritics to base letters, so "faleminderit" folds equal to a form
     * missing an ë. Used only to *detect* a near miss, never to accept one.
     */
    fun foldDiacritics(s: String): String =
        Normalizer.normalize(s, Normalizer.Form.NFD)
            .replace(Regex("\\p{Mn}+"), "")

    fun levenshtein(lhs: String, rhs: String): Int {
        val a = lhs.toCharArray()
        val b = rhs.toCharArray()
        if (a.isEmpty()) return b.size
        if (b.isEmpty()) return a.size

        var prev = IntArray(b.size + 1) { it }
        var curr = IntArray(b.size + 1)
        for (i in 1..a.size) {
            curr[0] = i
            for (j in 1..b.size) {
                val cost = if (a[i - 1] == b[j - 1]) 0 else 1
                curr[j] = minOf(prev[j] + 1, curr[j - 1] + 1, prev[j - 1] + cost)
            }
            val swap = prev
            prev = curr
            curr = swap
        }
        return prev[b.size]
    }
}

/** The outcome of grading one typed or chosen answer. Mirrors iOS `AnswerGrade`. */
enum class AnswerGrade { CORRECT, NEAR_MISS, INCORRECT }

/**
 * Grades an answer against the correct one, with the same precedence as iOS:
 * an exact accepted form is correct, otherwise a diacritic or single-typo
 * difference is a near miss, otherwise it is incorrect.
 */
fun gradeAnswer(submitted: String, correctAnswer: String): AnswerGrade {
    val normalized = AnswerNormalizer.normalize(submitted)
    val accepted = AnswerNormalizer.acceptedForms(correctAnswer)
    return when {
        normalized in accepted -> AnswerGrade.CORRECT
        AnswerNormalizer.isNearMiss(normalized, accepted) -> AnswerGrade.NEAR_MISS
        else -> AnswerGrade.INCORRECT
    }
}
