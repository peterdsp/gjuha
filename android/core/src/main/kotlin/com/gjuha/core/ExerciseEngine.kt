package com.gjuha.core

import kotlin.random.Random

/** The exercise shapes the engine can build. Mirrors the iOS `ExerciseType`. */
enum class ExerciseType {
    MULTIPLE_CHOICE_TRANSLATE,
    TRANSLATE_TEXT_INPUT,
    FILL_IN_BLANK,
    WORD_MATCH,
    ARRANGE_WORDS,
    TAP_WHAT_YOU_HEAR;

    companion object {
        /** Seed plan tokens to types, exactly as the iOS `mapPlanToken` does. */
        fun fromPlanToken(token: String): ExerciseType? = when (token.lowercase()) {
            "mcq" -> MULTIPLE_CHOICE_TRANSLATE
            "match" -> WORD_MATCH
            "word_order", "wordorder" -> ARRANGE_WORDS
            "typing", "type" -> TRANSLATE_TEXT_INPUT
            "listening", "listen" -> TAP_WHAT_YOU_HEAR
            "cloze", "fill_in_blank", "fillinblank" -> FILL_IN_BLANK
            else -> null
        }

        /** What a lesson gets when its plan names nothing this build understands. */
        val defaultPlan = listOf(MULTIPLE_CHOICE_TRANSLATE, TRANSLATE_TEXT_INPUT, FILL_IN_BLANK)

        fun plannedTypes(plan: List<String>): List<ExerciseType> =
            plan.mapNotNull { fromPlanToken(it) }.distinct().ifEmpty { defaultPlan }
    }
}

/** One Albanian/English pair in a matching exercise. */
data class MatchPair(val albanian: String, val english: String)

/**
 * A generated question.
 *
 * [orderedOptions] is decided once, at construction, and then stored. Reading it
 * never reshuffles, so options keep their positions for the life of the
 * exercise, including after feedback. The iOS version learned this the hard
 * way: a computed property that shuffled on every access made the buttons jump
 * on each view update.
 */
data class Exercise(
    val type: ExerciseType,
    val prompt: String,
    val correctAnswer: String,
    val distractors: List<String> = emptyList(),
    val hint: String? = null,
    val explanation: String? = null,
    val xpValue: Int,
    val pairs: List<MatchPair> = emptyList(),
    val orderedOptions: List<String> = emptyList(),
)

/**
 * Builds exercises from the seed vocabulary, ported from the iOS
 * `ExerciseEngine`.
 *
 * Two behaviours carry over because they are documented promises rather than
 * implementation details:
 *
 * - **Distractors are plausible, never random.** Preference order, each tier a
 *   safe fallback for the one before: same part of speech with matching
 *   secondary features, then same part of speech, then same CEFR level, then
 *   anything. Within a tier, candidates nearest the target's frequency come
 *   first so the options feel comparable.
 * - **An option that would also be correct is excluded.** A distractor whose
 *   accepted forms overlap the answer's makes a question unanswerable, so
 *   candidates are filtered through the same [AnswerNormalizer] that grades.
 *
 * [random] is injectable so tests get a fixed shuffle. What is under test is the
 * *selection*, which is deterministic; the order within a chosen band is not.
 */
class ExerciseEngine(
    private val allWords: List<SeedWord>,
    private val random: Random = Random.Default,
    /** Words with reviewed audio. Empty until recordings pass native review. */
    private val wordsWithAudio: Set<String> = emptySet(),
) {

    companion object {
        const val MAX_EXERCISES = 10
        private val fallbackEnglish = listOf("house", "water", "bread", "friend", "road")
        private val fallbackAlbanian = listOf("shtëpi", "ujë", "bukë", "mik", "rrugë")
    }

    fun pickDistractors(
        word: SeedWord,
        pool: List<SeedWord> = allWords,
        count: Int,
        useEnglish: Boolean,
    ): List<String> {
        val answerText: (SeedWord) -> String = { if (useEnglish) it.english else it.albanian }
        val correctForms = AnswerNormalizer.acceptedForms(answerText(word))

        fun isUsable(candidate: SeedWord): Boolean {
            if (candidate.id == word.id) return false
            val text = answerText(candidate).trim()
            if (text.isEmpty()) return false
            return AnswerNormalizer.acceptedForms(text).none { it in correctForms }
        }

        val usable = pool.filter(::isUsable)
        val samePosFeature = usable.filter {
            it.partOfSpeech == word.partOfSpeech && featureMatches(it, word)
        }
        val samePos = usable.filter { it.partOfSpeech == word.partOfSpeech }
        val sameLevel = usable.filter { it.cefrLevel == word.cefrLevel }

        val picked = mutableListOf<String>()
        val usedKeys = mutableSetOf<String>()

        fun take(candidates: List<SeedWord>) {
            if (picked.size >= count) return
            val band = candidates
                .sortedBy { frequencyDistance(it, word) }
                .take(maxOf(count * 4, 12))
                .shuffled(random)
            for (candidate in band) {
                if (picked.size >= count) break
                val text = answerText(candidate)
                if (!usedKeys.add(AnswerNormalizer.normalize(text))) continue
                picked += text
            }
        }

        take(samePosFeature)
        take(samePos)
        take(sameLevel)
        take(usable)

        if (picked.size < count) {
            for (filler in if (useEnglish) fallbackEnglish else fallbackAlbanian) {
                if (picked.size >= count) break
                val key = AnswerNormalizer.normalize(filler)
                if (key in correctForms || !usedKeys.add(key)) continue
                picked += filler
            }
        }
        return picked
    }

    /**
     * Matches secondary grammatical features when the dataset provides them.
     * The current A1 seed omits gender and verb class, so this returns true and
     * the part-of-speech tier does the work. It future-proofs richer datasets.
     */
    private fun featureMatches(candidate: SeedWord, word: SeedWord): Boolean {
        if (word.partOfSpeech == "noun" && word.gender != null && candidate.gender != null) {
            return word.gender == candidate.gender
        }
        if (word.partOfSpeech == "verb" && word.verbClass != null && candidate.verbClass != null) {
            return word.verbClass == candidate.verbClass
        }
        return true
    }

    private fun frequencyDistance(a: SeedWord, b: SeedWord): Int =
        kotlin.math.abs((a.frequency ?: 100_000) - (b.frequency ?: 100_000))

    private fun options(correct: String, distractors: List<String>): List<String> =
        (distractors + correct).shuffled(random)

    fun mcqAlbanianToEnglish(word: SeedWord): Exercise {
        val distractors = pickDistractors(word, count = 3, useEnglish = true)
        return Exercise(
            type = ExerciseType.MULTIPLE_CHOICE_TRANSLATE,
            prompt = "What does '${word.albanian}' mean?",
            correctAnswer = word.english,
            distractors = distractors,
            explanation = explanation(word),
            xpValue = 10,
            orderedOptions = options(word.english, distractors),
        )
    }

    fun mcqEnglishToAlbanian(word: SeedWord): Exercise {
        val distractors = pickDistractors(word, count = 3, useEnglish = false)
        return Exercise(
            type = ExerciseType.MULTIPLE_CHOICE_TRANSLATE,
            prompt = "How do you say '${word.english}' in Albanian?",
            correctAnswer = word.albanian,
            distractors = distractors,
            explanation = explanation(word),
            xpValue = 10,
            orderedOptions = options(word.albanian, distractors),
        )
    }

    /** Direction is fixed by word id so a lesson has a stable mix, as on iOS. */
    fun translateTextInput(word: SeedWord): Exercise = if (isEvenId(word.id)) {
        Exercise(
            type = ExerciseType.TRANSLATE_TEXT_INPUT,
            prompt = "Translate: '${word.english}'",
            correctAnswer = word.albanian,
            hint = "Type in Albanian",
            explanation = explanation(word),
            xpValue = 15,
        )
    } else {
        Exercise(
            type = ExerciseType.TRANSLATE_TEXT_INPUT,
            prompt = "Translate: '${word.albanian}'",
            correctAnswer = word.english,
            hint = "Type in English",
            explanation = explanation(word),
            xpValue = 15,
        )
    }

    fun arrangeWords(word: SeedWord): Exercise? {
        val sentence = word.exampleSentence?.trim().orEmpty()
        val translation = word.exampleTranslation?.trim().orEmpty()
        if (sentence.isEmpty() || translation.isEmpty()) return null

        val tokens = sentence.split(Regex("\\s+")).filter { it.isNotEmpty() }
        if (tokens.size < 3) return null

        // Shuffle into a start order that differs from the answer. A sentence of
        // identical tokens cannot, and is skipped rather than shipped unsolvable.
        var shuffled = tokens
        var attempts = 0
        while (shuffled == tokens && attempts < 8) {
            shuffled = tokens.shuffled(random)
            attempts++
        }
        if (shuffled == tokens) return null

        val correct = tokens.joinToString(" ")
        return Exercise(
            type = ExerciseType.ARRANGE_WORDS,
            prompt = "Arrange the words to say: \"$translation\"",
            correctAnswer = correct,
            hint = "Tap the words in order",
            explanation = explanation(word, extra = "Correct order: $correct."),
            xpValue = 15,
            orderedOptions = shuffled,
        )
    }

    fun fillInBlank(word: SeedWord): Exercise? {
        val sentence = word.exampleSentence?.trim().orEmpty()
        val translation = word.exampleTranslation?.trim().orEmpty()
        if (sentence.isEmpty() || translation.isEmpty()) return null
        if (!sentence.contains(word.albanian, ignoreCase = true)) return null

        val distractors = pickDistractors(word, count = 3, useEnglish = false)
        return Exercise(
            type = ExerciseType.FILL_IN_BLANK,
            prompt = "${sentence.replace(word.albanian, "___", ignoreCase = true)} ($translation)",
            correctAnswer = word.albanian,
            distractors = distractors,
            explanation = explanation(word, extra = "Full sentence: $sentence ($translation)."),
            xpValue = 12,
            orderedOptions = options(word.albanian, distractors),
        )
    }

    fun wordMatch(words: List<SeedWord>): Exercise? {
        val pairs = mutableListOf<MatchPair>()
        val albSeen = mutableSetOf<String>()
        val engSeen = mutableSetOf<String>()

        for (word in words) {
            val alb = AnswerNormalizer.normalize(word.albanian)
            val gloss = shortGloss(word.english)
            val eng = AnswerNormalizer.normalize(gloss)
            if (alb.isEmpty() || eng.isEmpty()) continue
            if (!albSeen.add(alb) || !engSeen.add(eng)) continue
            pairs += MatchPair(word.albanian, gloss)
            if (pairs.size == 4) break
        }
        if (pairs.size < 3) return null

        return Exercise(
            type = ExerciseType.WORD_MATCH,
            prompt = "Match each word to its meaning",
            correctAnswer = pairs.joinToString("|") { "${it.albanian}=${it.english}" },
            explanation = "Matching builds fast recognition of new words before you produce them.",
            xpValue = 12,
            pairs = pairs,
        )
    }

    /**
     * Only buildable for a word with reviewed audio. The app ships none, so this
     * returns null and the caller falls back to a translation prompt. Listening
     * is never faked with a synthetic voice that mispronounces Albanian.
     */
    fun listening(word: SeedWord): Exercise? {
        if (word.id !in wordsWithAudio) return null
        val distractors = pickDistractors(word, count = 3, useEnglish = false)
        return Exercise(
            type = ExerciseType.TAP_WHAT_YOU_HEAR,
            prompt = "Tap what you hear",
            correctAnswer = word.albanian,
            distractors = distractors,
            explanation = explanation(word),
            xpValue = 12,
            orderedOptions = options(word.albanian, distractors),
        )
    }

    /**
     * Builds a lesson's exercises from its plan.
     *
     * Matching is a grouped exercise over several words, so it is built once up
     * front when the plan asks for it; the remaining types rotate per word so a
     * lesson mixes formats instead of repeating one.
     */
    fun exercises(lesson: SeedLesson, lessonWords: List<SeedWord>): List<Exercise> {
        val words = lessonWords.ifEmpty { allWords.take(8) }
        if (words.isEmpty()) return emptyList()

        val planTypes = ExerciseType.plannedTypes(lesson.exercisePlan)
        val shuffled = words.shuffled(random)
        val exercises = mutableListOf<Exercise>()
        val usedWordIds = mutableSetOf<String>()

        if (ExerciseType.WORD_MATCH in planTypes) {
            wordMatch(shuffled)?.let { match ->
                exercises += match
                usedWordIds += match.pairs.mapNotNull { pair ->
                    shuffled.firstOrNull { it.albanian == pair.albanian }?.id
                }
            }
        }

        val perWordTypes = planTypes.filter { it != ExerciseType.WORD_MATCH }
        if (perWordTypes.isEmpty()) return exercises

        // Prefer words the match exercise did not use, so a lesson covers more
        // of its vocabulary; fall back to all of them if too few are left.
        var candidates = shuffled.filter { it.id !in usedWordIds }
        if (candidates.size < minOf(shuffled.size, 4)) candidates = shuffled

        var rotation = 0
        for (word in candidates) {
            if (exercises.size >= MAX_EXERCISES) break
            val built = buildRotating(perWordTypes, rotation, word) ?: continue
            exercises += built.first
            rotation = built.second
        }
        return exercises
    }

    /**
     * Takes the next type in the rotation this word can support, so a word with
     * no example sentence does not drop out of a lesson because word-order
     * happened to be next in line.
     */
    /**
     * Builds a review session over words that are due, pairing each exercise
     * with the word it is testing.
     *
     * The pairing is the point. A review reschedules the word behind the
     * exercise, so the caller has to know which word an answer was about;
     * deriving it from the prompt afterwards would break for word order and
     * cloze, where the prompt is a sentence rather than the word.
     *
     * Unlike a lesson this has no plan to follow, so it rotates every type the
     * word can support. Matching is left out: it covers four words at once and
     * so cannot reschedule any one of them from a single answer.
     */
    fun reviewExercises(dueWords: List<SeedWord>, limit: Int = MAX_EXERCISES): List<Pair<String, Exercise>> {
        if (dueWords.isEmpty()) return emptyList()

        val types = ExerciseType.entries.filter { it != ExerciseType.WORD_MATCH }
        val out = mutableListOf<Pair<String, Exercise>>()
        var rotation = 0

        for (word in dueWords.shuffled(random)) {
            if (out.size >= limit) break
            val built = buildRotating(types, rotation, word) ?: continue
            out += word.id to built.first
            rotation = built.second
        }
        return out
    }

    private fun buildRotating(
        types: List<ExerciseType>,
        startAt: Int,
        word: SeedWord,
    ): Pair<Exercise, Int>? {
        for (offset in types.indices) {
            val index = (startAt + offset) % types.size
            build(types[index], word)?.let { return it to (index + 1) % types.size }
        }
        return null
    }

    private fun build(type: ExerciseType, word: SeedWord): Exercise? = when (type) {
        ExerciseType.MULTIPLE_CHOICE_TRANSLATE ->
            if (isEvenId(word.id)) mcqEnglishToAlbanian(word) else mcqAlbanianToEnglish(word)
        ExerciseType.TRANSLATE_TEXT_INPUT -> translateTextInput(word)
        ExerciseType.ARRANGE_WORDS -> arrangeWords(word) ?: mcqAlbanianToEnglish(word)
        ExerciseType.TAP_WHAT_YOU_HEAR -> listening(word) ?: mcqAlbanianToEnglish(word)
        ExerciseType.FILL_IN_BLANK -> fillInBlank(word) ?: mcqAlbanianToEnglish(word)
        ExerciseType.WORD_MATCH -> null
    }

    /** The part before any "/" or "(", trimmed. Matches the iOS `shortGloss`. */
    private fun shortGloss(english: String): String =
        english.substringBefore('/').substringBefore('(').trim().ifEmpty { english }

    private fun isEvenId(id: String): Boolean =
        (id.dropWhile { !it.isDigit() }.takeWhile { it.isDigit() }.toIntOrNull() ?: 0) % 2 == 0

    private fun explanation(word: SeedWord, extra: String? = null): String {
        val base = "${word.albanian} means ${word.english}."
        return if (extra == null) base else "$base $extra"
    }
}
