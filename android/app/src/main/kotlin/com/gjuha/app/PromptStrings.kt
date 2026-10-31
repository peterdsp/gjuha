package com.gjuha.app

import androidx.compose.runtime.Composable
import androidx.compose.ui.res.stringResource
import com.gjuha.core.Exercise
import com.gjuha.core.PromptSpec

/**
 * Asks a question in the language the interface is running in.
 *
 * The engine still produces an English prompt and that stays the fallback, so
 * a question is never blank: an exercise built before this existed, or a shape
 * added later and not mapped here, still reads correctly.
 *
 * The subject of a question is never translated. "What does 'mirëdita' mean?"
 * is about that word, and the word is the material being taught.
 */
@Composable
fun localizedPrompt(exercise: Exercise): String {
    val spec = exercise.promptSpec ?: return exercise.prompt
    return when (spec.kind) {
        PromptSpec.Kind.MEANING_OF ->
            stringResource(R.string.prompt_meaning_of, spec.argument)
        PromptSpec.Kind.SAY_IN_ALBANIAN ->
            stringResource(R.string.prompt_say_in_albanian, spec.argument)
        PromptSpec.Kind.TRANSLATE_TO_ALBANIAN,
        PromptSpec.Kind.TRANSLATE_TO_ENGLISH ->
            stringResource(R.string.prompt_translate, spec.argument)
        PromptSpec.Kind.ARRANGE_WORDS ->
            stringResource(R.string.prompt_arrange, spec.argument)
        PromptSpec.Kind.FILL_THE_BLANK ->
            // Both parts, because the sentence alone is unanswerable without
            // knowing what it is meant to say.
            stringResource(R.string.prompt_fill_blank, spec.argument, spec.secondary)
        PromptSpec.Kind.MATCH_PAIRS ->
            stringResource(R.string.prompt_match_pairs)
        PromptSpec.Kind.TAP_WHAT_YOU_HEAR ->
            stringResource(R.string.prompt_tap_what_you_hear)
    }
}

/**
 * The instruction under a typed or arranged answer.
 *
 * Derived from the question's shape rather than from the engine's English
 * hint, so it is translated by the same route as the prompt.
 */
@Composable
fun localizedHint(exercise: Exercise): String? = when (exercise.promptSpec?.kind) {
    PromptSpec.Kind.TRANSLATE_TO_ALBANIAN -> stringResource(R.string.hint_type_in_albanian)
    PromptSpec.Kind.TRANSLATE_TO_ENGLISH -> stringResource(R.string.hint_type_in_english)
    PromptSpec.Kind.ARRANGE_WORDS -> stringResource(R.string.hint_tap_in_order)
    else -> exercise.hint
}
