package com.gjuha.app

import androidx.compose.foundation.layout.*
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.text.KeyboardActions
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.gjuha.core.AnswerGrade
import com.gjuha.core.AnswerNormalizer
import com.gjuha.core.Exercise
import com.gjuha.core.ExerciseEngine
import com.gjuha.core.ExerciseType
import com.gjuha.core.ReviewGrade
import com.gjuha.core.SeedLesson
import com.gjuha.core.toReviewGrade
import com.gjuha.core.gradeAnswer
import kotlinx.coroutines.delay

/**
 * A lesson session.
 *
 * The rules it enforces are the iOS ones, and they are the reason this screen is
 * not just a quiz:
 *
 * - **A near miss is not a pass.** Dropping an Albanian diacritic is recognised,
 *   named, and not accepted. It costs a heart like any wrong answer.
 * - **XP is banked once, on completion.** Leaving part way through earns
 *   nothing, so a count can never be inflated by starting a lesson repeatedly.
 * - **The combo bonus is the same**: five extra XP for every third correct
 *   answer in a row, and a wrong answer resets the run.
 */
@Composable
fun LessonScreen(
    lesson: SeedLesson,
    content: ContentRepository,
    onFinished: (xpEarned: Int, wordIds: List<String>) -> Unit,
    onQuit: () -> Unit,
) {
    val lessonWords = remember(lesson.id) { content.wordsFor(lesson) }
    val exercises = remember(lesson.id) {
        ExerciseEngine(content.words).exercises(lesson, lessonWords)
    }
    LessonSession(
        exercises = exercises,
        wordIdByIndex = emptyMap(),
        onReviewOutcome = null,
        onFinished = { xp -> onFinished(xp, lessonWords.map { it.id }) },
        onQuit = onQuit,
    )
}

/**
 * A review session over words the scheduler says are due.
 *
 * It reuses the lesson session rather than reimplementing one, which is what
 * iOS does too, and for the same reason: the grading, the feedback and the
 * combo are the same behaviour, and a second copy of them would drift.
 *
 * Three rules differ, and all three protect the schedule:
 *
 * - **Every word is rescheduled as it is answered**, not at the end, so a
 *   session abandoned half way still records what it measured.
 * - **A review always advances**, whatever the grade. Retry-until-correct would
 *   re-record the same word and corrupt its spacing.
 * - **There are no hearts.** Failing a review is the normal way to find out a
 *   word needs more work, so it cannot end the session.
 */
@Composable
fun ReviewScreen(
    content: ContentRepository,
    progress: ProgressRepository,
    onFinished: (xpEarned: Int) -> Unit,
    onQuit: () -> Unit,
) {
    val session = remember {
        val dueIds = progress.dueWordIds()
        val dueWords = dueIds.mapNotNull { id -> content.words.firstOrNull { it.id == id } }
        ExerciseEngine(content.words).reviewExercises(dueWords)
    }

    LessonSession(
        exercises = session.map { it.second },
        wordIdByIndex = session.indices.associateWith { session[it].first },
        onReviewOutcome = { wordId, grade -> progress.recordReviewOutcome(wordId, grade) },
        onFinished = onFinished,
        onQuit = onQuit,
    )
}

/**
 * The shared session body. [wordIdByIndex] being non-empty makes it a review.
 */
@Composable
private fun LessonSession(
    exercises: List<Exercise>,
    wordIdByIndex: Map<Int, String>,
    onReviewOutcome: ((String, ReviewGrade) -> Unit)?,
    onFinished: (xpEarned: Int) -> Unit,
    onQuit: () -> Unit,
) {
    val isReview = onReviewOutcome != null

    var index by remember { mutableIntStateOf(0) }
    var hearts by remember { mutableIntStateOf(3) }
    var xp by remember { mutableIntStateOf(0) }
    var combo by remember { mutableIntStateOf(0) }
    var bestCombo by remember { mutableIntStateOf(0) }
    var answered by remember { mutableIntStateOf(0) }
    var correctCount by remember { mutableIntStateOf(0) }
    var feedback by remember { mutableStateOf<Feedback?>(null) }

    val finished = index >= exercises.size
    val failed = !isReview && hearts <= 0

    // Advance after showing the outcome, as on iOS. A wrong answer still moves
    // on: the word returns through the review schedule rather than by making
    // the learner guess until they stumble on it.
    LaunchedEffect(feedback) {
        val shown = feedback ?: return@LaunchedEffect
        delay(1400)
        feedback = null
        // A review always advances: the word has been rescheduled once already,
        // and asking again would record the same recall twice.
        if (!isReview && shown.grade != AnswerGrade.CORRECT && hearts <= 0) return@LaunchedEffect
        index++
    }

    when {
        exercises.isEmpty() -> EmptyLesson(onQuit)
        failed -> OutOfHearts(onQuit)
        finished -> LessonComplete(
            xp = xp,
            accuracy = if (answered == 0) null else correctCount.toDouble() / answered,
            answered = answered,
            bestCombo = bestCombo,
            isReview = isReview,
            onContinue = { onFinished(xp) },
        )
        else -> {
            val exercise = exercises[index]
            Column(Modifier.fillMaxSize().padding(16.dp)) {
                LessonHeader(
                    progress = index.toFloat() / exercises.size,
                    hearts = if (isReview) null else hearts,
                    combo = combo,
                    onQuit = onQuit,
                )
                Spacer(Modifier.height(24.dp))
                ExerciseBody(
                    exercise = exercise,
                    enabled = feedback == null,
                ) { submitted ->
                    val grade = gradeAnswer(submitted, exercise.correctAnswer)
                    answered++
                    when (grade) {
                        AnswerGrade.CORRECT -> {
                            correctCount++
                            combo++
                            bestCombo = maxOf(bestCombo, combo)
                            // Five extra XP every third correct in a row.
                            xp += exercise.xpValue + if (combo % 3 == 0) 5 else 0
                        }
                        AnswerGrade.NEAR_MISS, AnswerGrade.INCORRECT -> {
                            combo = 0
                            // A review has no hearts: being wrong is how a word
                            // is found to need more work, not a way to fail.
                            if (!isReview) hearts--
                        }
                    }
                    // Reschedule now rather than at the end, so quitting half
                    // way still records what was measured.
                    wordIdByIndex[index]?.let { wordId ->
                        onReviewOutcome?.invoke(wordId, grade.toReviewGrade())
                    }
                    feedback = Feedback(
                        grade = grade,
                        correctAnswer = exercise.correctAnswer,
                        hint = if (grade == AnswerGrade.NEAR_MISS) {
                            AnswerNormalizer.diacriticHint(submitted, exercise.correctAnswer)
                        } else null,
                    )
                }
                Spacer(Modifier.weight(1f))
                feedback?.let { FeedbackBanner(it) }
            }
        }
    }
}

private data class Feedback(
    val grade: AnswerGrade,
    val correctAnswer: String,
    val hint: String?,
)

@Composable
private fun LessonHeader(progress: Float, hearts: Int?, combo: Int, onQuit: () -> Unit) {
    Row(verticalAlignment = Alignment.CenterVertically) {
        TextButton(onClick = onQuit) { Text(stringResource(R.string.exit_lesson)) }
        LinearProgressIndicator(
            progress = { progress },
            modifier = Modifier.weight(1f).padding(horizontal = 8.dp),
        )
        if (combo >= 2) {
            Text("${combo}x", color = xpStrong(), fontWeight = FontWeight.Bold)
            Spacer(Modifier.width(8.dp))
        }
        if (hearts != null) {
            Text("❤".repeat(hearts.coerceAtLeast(0)))
        } else {
            // A review shows what it is instead of a heart count it does not keep.
            Text(stringResource(R.string.daily_review), fontSize = 13.sp, color = MaterialTheme.colorScheme.onSurfaceVariant)
        }
    }
}

@Composable
private fun ExerciseBody(exercise: Exercise, enabled: Boolean, onAnswer: (String) -> Unit) {
    Column(Modifier.fillMaxWidth().verticalScroll(rememberScrollState())) {
        Text(
            exercise.prompt,
            fontSize = 22.sp,
            fontWeight = FontWeight.SemiBold,
            textAlign = TextAlign.Center,
            modifier = Modifier.fillMaxWidth(),
        )
        Spacer(Modifier.height(24.dp))

        when (exercise.type) {
            ExerciseType.TRANSLATE_TEXT_INPUT -> TypedAnswer(exercise, enabled, onAnswer)
            ExerciseType.WORD_MATCH -> MatchAnswer(exercise, enabled, onAnswer)
            ExerciseType.ARRANGE_WORDS -> ArrangeAnswer(exercise, enabled, onAnswer)
            else -> OptionAnswer(exercise, enabled, onAnswer)
        }
    }
}

@Composable
private fun OptionAnswer(exercise: Exercise, enabled: Boolean, onAnswer: (String) -> Unit) {
    Column(verticalArrangement = Arrangement.spacedBy(10.dp)) {
        for (option in exercise.orderedOptions) {
            OutlinedButton(
                onClick = { onAnswer(option) },
                enabled = enabled,
                modifier = Modifier.fillMaxWidth().heightIn(min = 48.dp),
            ) {
                Text(option, fontSize = 16.sp)
            }
        }
    }
}

@Composable
private fun TypedAnswer(exercise: Exercise, enabled: Boolean, onAnswer: (String) -> Unit) {
    var typed by remember(exercise.prompt) { mutableStateOf("") }
    Column {
        OutlinedTextField(
            value = typed,
            onValueChange = { typed = it },
            enabled = enabled,
            singleLine = true,
            label = { Text(exercise.hint ?: "Your answer") },
            modifier = Modifier.fillMaxWidth(),
        )
        Spacer(Modifier.height(12.dp))
        Button(
            onClick = { onAnswer(typed) },
            enabled = enabled && typed.isNotBlank(),
            modifier = Modifier.fillMaxWidth().heightIn(min = 48.dp),
        ) {
            Text(stringResource(R.string.check_action))
        }
    }
}

@Composable
private fun ArrangeAnswer(exercise: Exercise, enabled: Boolean, onAnswer: (String) -> Unit) {
    val placed = remember(exercise.prompt) { mutableStateListOf<Int>() }
    Column {
        // The assembled sentence is built from the same tappable tokens, so a
        // mistake is taken back by tapping the word rather than restarting the
        // question. Without this the only way out of a wrong tap is a wrong
        // answer, which would cost a heart for a slip rather than for not
        // knowing the sentence.
        if (placed.isEmpty()) {
            Text(
                "Tap the words in order",
                fontSize = 15.sp,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
            )
        } else {
            FlowTokens(
                tokens = placed.toList(),
                label = { exercise.orderedOptions[it] },
                enabled = enabled,
            ) { placed.remove(it) }
        }
        Spacer(Modifier.height(16.dp))
        HorizontalDivider()
        Spacer(Modifier.height(16.dp))
        FlowTokens(
            tokens = exercise.orderedOptions.indices.filterNot { it in placed },
            label = { exercise.orderedOptions[it] },
            enabled = enabled,
        ) { placed.add(it) }
        Spacer(Modifier.height(16.dp))
        Button(
            onClick = { onAnswer(placed.joinToString(" ") { exercise.orderedOptions[it] }) },
            enabled = enabled && placed.isNotEmpty(),
            modifier = Modifier.fillMaxWidth().heightIn(min = 48.dp),
        ) {
            Text(stringResource(R.string.check_action))
        }
    }
}

@Composable
private fun FlowTokens(
    tokens: List<Int>,
    label: (Int) -> String,
    enabled: Boolean,
    onTap: (Int) -> Unit,
) {
    // Simple wrapping rows; a lesson sentence is short enough that three per
    // row is always enough and avoids pulling in an extra layout dependency.
    tokens.chunked(3).forEach { row ->
        Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
            row.forEach { index ->
                OutlinedButton(onClick = { onTap(index) }, enabled = enabled) {
                    Text(label(index))
                }
            }
        }
        Spacer(Modifier.height(8.dp))
    }
}

@Composable
private fun MatchAnswer(exercise: Exercise, enabled: Boolean, onAnswer: (String) -> Unit) {
    val matched = remember(exercise.prompt) { mutableStateListOf<String>() }
    var selected by remember(exercise.prompt) { mutableStateOf<String?>(null) }

    LaunchedEffect(matched.size) {
        if (matched.size == exercise.pairs.size && exercise.pairs.isNotEmpty()) {
            onAnswer(exercise.correctAnswer)
        }
    }

    Row(horizontalArrangement = Arrangement.spacedBy(12.dp)) {
        Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(8.dp)) {
            exercise.pairs.forEach { pair ->
                OutlinedButton(
                    onClick = { selected = pair.albanian },
                    enabled = enabled && pair.albanian !in matched,
                    modifier = Modifier.fillMaxWidth(),
                ) { Text(pair.albanian) }
            }
        }
        Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(8.dp)) {
            exercise.pairs.forEach { pair ->
                OutlinedButton(
                    onClick = {
                        if (selected == pair.albanian) matched.add(pair.albanian)
                        selected = null
                    },
                    enabled = enabled && pair.albanian !in matched,
                    modifier = Modifier.fillMaxWidth(),
                ) { Text(pair.english) }
            }
        }
    }
}

@Composable
private fun FeedbackBanner(feedback: Feedback) {
    val (container, title) = when (feedback.grade) {
        AnswerGrade.CORRECT -> GjuhaColors.Success to stringResource(R.string.correct)
        AnswerGrade.NEAR_MISS -> GjuhaColors.Streak to stringResource(R.string.near_miss)
        AnswerGrade.INCORRECT -> GjuhaColors.Error to "Not quite..."
    }
    Card(colors = CardDefaults.cardColors(containerColor = container)) {
        Column(Modifier.fillMaxWidth().padding(16.dp)) {
            Text(title, color = GjuhaColors.OnAccent, fontWeight = FontWeight.Bold)
            if (feedback.grade != AnswerGrade.CORRECT) {
                Text(
                    "Answer: ${feedback.correctAnswer}",
                    color = GjuhaColors.OnAccent,
                    fontSize = 13.sp,
                )
            }
            feedback.hint?.let {
                Spacer(Modifier.height(4.dp))
                Text(it, color = GjuhaColors.OnAccent, fontSize = 13.sp)
            }
        }
    }
}

@Composable
private fun LessonComplete(
    xp: Int,
    accuracy: Double?,
    answered: Int,
    bestCombo: Int,
    isReview: Boolean,
    onContinue: () -> Unit,
) {
    Column(
        Modifier.fillMaxSize().padding(24.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.Center,
    ) {
        Text("⭐", fontSize = 56.sp)
        Spacer(Modifier.height(16.dp))
        Text(
            stringResource(if (isReview) R.string.review_complete else R.string.lesson_complete),
            fontSize = 24.sp,
            fontWeight = FontWeight.Bold,
        )
        Text("+$xp XP", fontSize = 32.sp, fontWeight = FontWeight.Bold, color = accentStrong())
        Spacer(Modifier.height(24.dp))
        Row(horizontalArrangement = Arrangement.spacedBy(12.dp)) {
            // Omitted rather than shown as zero when nothing was graded, so the
            // screen never states an accuracy that was not measured.
            accuracy?.let {
                SummaryTile(stringResource(R.string.accuracy), "${(it * 100).toInt()}%")
            }
            SummaryTile(stringResource(R.string.questions), answered.toString())
            if (bestCombo >= 2) SummaryTile(stringResource(R.string.best_streak), "${bestCombo}x")
        }
        Spacer(Modifier.height(32.dp))
        Button(
            onClick = onContinue,
            modifier = Modifier.fillMaxWidth().heightIn(min = 48.dp),
        ) { Text(stringResource(R.string.continue_action)) }
    }
}

@Composable
private fun SummaryTile(label: String, value: String) {
    Card {
        Column(
            Modifier.padding(16.dp),
            horizontalAlignment = Alignment.CenterHorizontally,
        ) {
            Text(value, fontSize = 20.sp, fontWeight = FontWeight.Bold)
            Text(label, fontSize = 12.sp, color = MaterialTheme.colorScheme.onSurfaceVariant)
        }
    }
}

@Composable
private fun OutOfHearts(onQuit: () -> Unit) {
    Column(
        Modifier.fillMaxSize().padding(24.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.Center,
    ) {
        Text("💔", fontSize = 56.sp)
        Spacer(Modifier.height(16.dp))
        Text(stringResource(R.string.out_of_hearts), fontSize = 22.sp, fontWeight = FontWeight.Bold)
        Text(
            stringResource(R.string.practice_more),
            color = MaterialTheme.colorScheme.onSurfaceVariant,
            textAlign = TextAlign.Center,
        )
        Spacer(Modifier.height(24.dp))
        // No XP is banked. A lesson that was not finished earns nothing, so a
        // count can never be inflated by starting one repeatedly.
        Button(onClick = onQuit) { Text(stringResource(R.string.back_to_lessons)) }
    }
}

@Composable
private fun EmptyLesson(onQuit: () -> Unit) {
    Column(
        Modifier.fillMaxSize().padding(24.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.Center,
    ) {
        Text("This lesson has no exercises yet.")
        Spacer(Modifier.height(16.dp))
        Button(onClick = onQuit) { Text("Back") }
    }
}
