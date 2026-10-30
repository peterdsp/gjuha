package com.gjuha.core

import kotlinx.serialization.Serializable
import kotlinx.serialization.json.Json

/**
 * A lesson in progress, durable enough to survive the app being killed.
 *
 * The generated exercises are stored rather than regenerated on resume. This is
 * the whole point: generation shuffles options and picks distractors from a
 * random source, so regenerating would hand the learner a different lesson than
 * the one they were halfway through.
 *
 * [xpEarned] is an accumulator for this attempt only. It is banked into the
 * lifetime total exactly once, on completion, so restoring it can never double
 * count. That is the property worth testing, because getting it wrong inflates
 * a number the learner trusts.
 */
@Serializable
data class LessonSessionSnapshot(
    val lessonId: String,
    val exercises: List<Exercise>,
    val currentIndex: Int,
    val hearts: Int,
    val xpEarned: Int,
    val combo: Int,
    val bestCombo: Int,
    val answeredCount: Int,
    val correctCount: Int,
    /** Review sessions are not resumable: their words are already rescheduled. */
    val isReview: Boolean = false,
) {
    /** A session with nothing left to answer should not be offered as a resume. */
    val isResumable: Boolean
        get() = !isReview &&
            exercises.isNotEmpty() &&
            currentIndex in exercises.indices &&
            hearts > 0

    companion object {
        private val json = Json { ignoreUnknownKeys = true }

        fun encode(snapshot: LessonSessionSnapshot): String = json.encodeToString(snapshot)

        /**
         * Decodes a stored session, returning null rather than throwing.
         *
         * A half written or outdated value means the learner loses one partial
         * lesson, which is a far smaller harm than a crash on launch.
         */
        fun decode(raw: String?): LessonSessionSnapshot? {
            if (raw.isNullOrBlank()) return null
            return runCatching { json.decodeFromString<LessonSessionSnapshot>(raw) }.getOrNull()
        }
    }
}
