package com.gjuha.app

import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.activity.enableEdgeToEdge
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.semantics.clearAndSetSemantics
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.semantics.stateDescription
import androidx.compose.ui.draw.clip
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.compose.ui.platform.LocalContext
import com.gjuha.app.widget.WidgetPublisher
import com.gjuha.core.AchievementCatalog
import com.gjuha.core.LearningGoal
import com.gjuha.core.Exercise
import com.gjuha.core.ExerciseEngine
import com.gjuha.core.ExerciseType
import com.gjuha.core.SeedLesson
import com.gjuha.core.UserStats
import com.gjuha.core.gradeAnswer
import com.gjuha.core.AnswerGrade

class MainActivity : ComponentActivity() {

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        enableEdgeToEdge()

        val content = ContentRepository(applicationContext)
        val progress = ProgressRepository(applicationContext)

        setContent {
            GjuhaTheme {
                Surface(
                    modifier = Modifier.fillMaxSize(),
                    color = MaterialTheme.colorScheme.background,
                ) {
                    GjuhaApp(content, progress)
                }
            }
        }
    }
}

private enum class Screen { LEARN, WORDS, GRAMMAR, PROFILE }

@Composable
private fun GjuhaApp(content: ContentRepository, progress: ProgressRepository) {
    var screen by remember { mutableStateOf(Screen.LEARN) }
    var openLesson by remember { mutableStateOf<SeedLesson?>(null) }
    var inReview by remember { mutableStateOf(false) }
    var onboarded by remember { mutableStateOf(progress.hasCompletedOnboarding) }
    // Bumped whenever progress changes, so the screens re-read their figures.
    var revision by remember { mutableIntStateOf(0) }

    // The widget renders a projection rather than computing anything, so it is
    // republished on every change to learner state. Keyed on the same revision
    // the screens use, so the widget cannot disagree with the Profile.
    val context = LocalContext.current
    LaunchedEffect(revision, onboarded) {
        if (onboarded) WidgetPublisher.publish(context, content, progress)
    }

    if (!onboarded) {
        OnboardingScreen(initial = progress.goal) { chosen ->
            progress.goal = chosen
            progress.hasCompletedOnboarding = true
            onboarded = true
            revision++
        }
        return
    }

    val stats = remember(revision) { progress.stats() }
    val completed = remember(revision) { progress.completedLessonIds }
    val dueCount = remember(revision) { progress.dueCount() }

    if (inReview) {
        ReviewScreen(
            content = content,
            progress = progress,
            onFinished = { xp ->
                // Banks XP and counts the day, but completes no lesson and
                // advances nothing in the course: the words were rescheduled
                // as they were answered.
                progress.recordReviewActivity(xp)
                val unlocked = progress.recordUnlocks()
                revision++
                unlocked.mapNotNull { AchievementCatalog.achievement(it) }
            },
            onQuit = {
                // Outcomes were recorded per answer, so leaving early keeps
                // what was measured and simply banks no XP.
                revision++
                inReview = false
            },
        )
        return
    }

    val lesson = openLesson
    if (lesson != null) {
        LessonScreen(
            lesson = lesson,
            content = content,
            progress = progress,
            onFinished = { xp, wordIds ->
                progress.completeLesson(lesson.id, xp, wordIds)
                val unlocked = progress.recordUnlocks()
                revision++
                unlocked.mapNotNull { AchievementCatalog.achievement(it) }
            },
            onQuit = { revision++; openLesson = null },
        )
        return
    }

    Scaffold(
        bottomBar = {
            NavigationBar {
                // The same four destinations as iOS, in the same order, so the
                // two apps are not navigated differently.
                for (tab in Screen.entries) {
                    NavigationBarItem(
                        selected = screen == tab,
                        onClick = { screen = tab },
                        label = { Text(stringResource(tab.title)) },
                        icon = {
                            Text(
                                tab.glyph,
                                fontSize = 18.sp,
                                // Decorative: the label already names the tab,
                                // so a screen reader saying "high voltage" here
                                // would only add noise.
                                modifier = Modifier.clearAndSetSemantics {},
                            )
                        },
                    )
                }
            }
        },
    ) { padding ->
        Box(Modifier.padding(padding)) {
            when (screen) {
                Screen.LEARN -> LearnScreen(
                    content = content,
                    stats = stats,
                    completed = completed,
                    dueCount = dueCount,
                    onStartReview = { inReview = true },
                    onOpen = { openLesson = it },
                )
                Screen.WORDS -> WordsScreen(content, progress)
                Screen.GRAMMAR -> GrammarScreen(content)
                Screen.PROFILE -> ProfileScreen(progress, stats) { revision++ }
            }
        }
    }
}

// MARK: - Learn

private val Screen.title: Int
    get() = when (this) {
        Screen.LEARN -> R.string.tab_learn
        Screen.WORDS -> R.string.tab_words
        Screen.GRAMMAR -> R.string.tab_grammar
        Screen.PROFILE -> R.string.tab_profile
    }

private val Screen.glyph: String
    get() = when (this) {
        Screen.LEARN -> "⚡"
        Screen.WORDS -> "📖"
        Screen.GRAMMAR -> "📚"
        Screen.PROFILE -> "👤"
    }

@Composable
private fun LearnScreen(
    content: ContentRepository,
    stats: UserStats,
    completed: Set<String>,
    dueCount: Int,
    onStartReview: () -> Unit,
    onOpen: (SeedLesson) -> Unit,
) {
    // Every unit, not just the first. The seed ships twelve of them and a
    // hundred and twenty lessons; showing one left a learner who finished it
    // at a dead end with the rest of the course unreachable.
    val units = remember { content.units.sortedBy { it.unit } }
    val lessonsByUnit = remember(units) { units.associateWith { content.lessons(it) } }

    LazyColumn(
        modifier = Modifier.fillMaxSize(),
        contentPadding = PaddingValues(16.dp),
        verticalArrangement = Arrangement.spacedBy(12.dp),
    ) {
        item { HeaderCard(stats) }

        // Only shown when something is actually due. A permanent Review button
        // that opens an empty session teaches people to ignore it.
        if (dueCount > 0) {
            item { ReviewCard(dueCount, onStartReview) }
        }

        for (unit in units) {
            val lessons = lessonsByUnit[unit].orEmpty()
            val done = lessons.count { it.id in completed }

            item(key = "unit-${unit.unit}") {
                Card(Modifier.fillMaxWidth()) {
                    Column(Modifier.padding(16.dp)) {
                        Text(
                            "Unit ${unit.unit} - ${unit.title}",
                            fontSize = 20.sp,
                            fontWeight = FontWeight.Bold,
                        )
                        Spacer(Modifier.height(4.dp))
                        Text(
                            stringResource(R.string.lessons_of, done, lessons.size),
                            color = MaterialTheme.colorScheme.onSurfaceVariant,
                            fontSize = 13.sp,
                        )
                        Spacer(Modifier.height(8.dp))
                        LinearProgressIndicator(
                            progress = {
                                if (lessons.isEmpty()) 0f else done.toFloat() / lessons.size
                            },
                            modifier = Modifier.fillMaxWidth(),
                            color = if (done == lessons.size && lessons.isNotEmpty()) {
                                successStrong()
                            } else {
                                accentStrong()
                            },
                        )
                    }
                }
            }

            items(lessons, key = { it.id }) { lesson ->
                val isDone = lesson.id in completed
                // A lesson opens once everything it requires is finished. The
                // rule comes from the seed, not from a hardcoded index, so it
                // carries across unit boundaries without any extra handling.
                val isLocked = lesson.unlock.requiresLessonIds.any { it !in completed }
                LessonRow(lesson, isDone, isLocked) { if (!isLocked) onOpen(lesson) }
            }
        }
    }
}

@Composable
private fun ReviewCard(dueCount: Int, onStart: () -> Unit) {
    val announcement = stringResource(R.string.a11y_start_review)
    Card(
        onClick = onStart,
        modifier = Modifier
            .fillMaxWidth()
            .semantics(mergeDescendants = true) { contentDescription = announcement },
        colors = CardDefaults.cardColors(containerColor = GjuhaColors.Success),
    ) {
        Row(
            Modifier.fillMaxWidth().padding(16.dp),
            verticalAlignment = Alignment.CenterVertically,
        ) {
            Text("\uD83D\uDD01", fontSize = 22.sp)
            Spacer(Modifier.width(12.dp))
            Column(Modifier.weight(1f)) {
                Text(
                    stringResource(R.string.daily_review),
                    fontWeight = FontWeight.Bold,
                    color = GjuhaColors.OnAccent,
                )
                Text(
                    if (dueCount == 1) "1 word is ready" else "$dueCount words are ready",
                    fontSize = 13.sp,
                    color = GjuhaColors.OnAccent,
                )
            }
            Text("\u25B6", color = GjuhaColors.OnAccent)
        }
    }
}

@Composable
private fun HeaderCard(stats: UserStats) {
    Card(Modifier.fillMaxWidth()) {
        Row(
            Modifier.fillMaxWidth().padding(16.dp),
            horizontalArrangement = Arrangement.SpaceBetween,
            verticalAlignment = Alignment.CenterVertically,
        ) {
            Metric("🔥", stats.currentStreak.toString(), streakStrong(), stringResource(R.string.day_streak))
            Column(horizontalAlignment = Alignment.CenterHorizontally) {
                Text(stringResource(R.string.today), fontSize = 12.sp, color = MaterialTheme.colorScheme.onSurfaceVariant)
                Text(
                    stringResource(R.string.xp_of, stats.xpToday, stats.dailyGoalXp),
                    fontWeight = FontWeight.Bold,
                    fontSize = 14.sp,
                )
                Spacer(Modifier.height(4.dp))
                LinearProgressIndicator(
                    progress = { stats.dailyGoalProgress.toFloat() },
                    modifier = Modifier.width(110.dp),
                    color = if (stats.hasMetDailyGoal) successStrong() else accentStrong(),
                )
            }
            Metric("⭐", stats.totalXp.toString(), xpStrong(), stringResource(R.string.total_xp))
        }
    }
}

@Composable
private fun Metric(
    glyph: String,
    value: String,
    tint: androidx.compose.ui.graphics.Color,
    label: String,
) {
    // Announced as one phrase, because "fire, 2" is not a fact.
    Row(
        verticalAlignment = Alignment.CenterVertically,
        modifier = Modifier.semantics(mergeDescendants = true) {
            contentDescription = "$label: $value"
        },
    ) {
        // The parent row already announces "label: value", so the glyph is
        // cleared rather than left to merge in as a second reading of it.
        Text(glyph, fontSize = 16.sp, modifier = Modifier.clearAndSetSemantics {})
        Spacer(Modifier.width(4.dp))
        Text(value, color = tint, fontWeight = FontWeight.Bold)
    }
}

@Composable
private fun LessonRow(lesson: SeedLesson, isDone: Boolean, isLocked: Boolean, onClick: () -> Unit) {
    val state = stringResource(
        if (isLocked) R.string.a11y_locked_hint else R.string.a11y_unlocked
    )
    Card(
        Modifier
            .fillMaxWidth()
            .clickable(enabled = !isLocked, onClick = onClick)
            // Merged so the row is one announcement, with the lock or tick
            // spoken as a state rather than as an emoji.
            .semantics(mergeDescendants = true) { stateDescription = state },
    ) {
        Row(
            Modifier.fillMaxWidth().padding(16.dp),
            verticalAlignment = Alignment.CenterVertically,
        ) {
            Box(
                Modifier.size(40.dp).clip(CircleShape).background(
                    when {
                        isDone -> GjuhaColors.Success
                        isLocked -> MaterialTheme.colorScheme.surfaceVariant
                        else -> GjuhaColors.Accent
                    }
                ),
                contentAlignment = Alignment.Center,
            ) {
                Text(
                    if (isDone) "✓" else if (isLocked) "🔒" else "▶",
                    color = if (isLocked) MaterialTheme.colorScheme.onSurfaceVariant else GjuhaColors.OnAccent,
                    // Decorative: the row announces its state, so a
                    // screen reader reading "lock" here would say it twice.
                    modifier = Modifier.clearAndSetSemantics {},
                )
            }
            Spacer(Modifier.width(12.dp))
            Column(Modifier.weight(1f)) {
                Text(lesson.title, fontWeight = FontWeight.SemiBold)
                Text(
                    lesson.cefr.uppercase(),
                    fontSize = 12.sp,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                )
            }
        }
    }
}

// MARK: - Profile

@Composable
private fun ProfileScreen(
    progress: ProgressRepository,
    stats: UserStats,
    onChanged: () -> Unit,
) {
    val unlocked = remember(stats) { progress.unlockedAchievementIds() }
    var goal by remember(stats) { mutableStateOf(progress.goal) }

    LazyColumn(
        modifier = Modifier.fillMaxSize(),
        contentPadding = PaddingValues(16.dp),
        verticalArrangement = Arrangement.spacedBy(12.dp),
    ) {
        item {
            Card(Modifier.fillMaxWidth()) {
                Column(Modifier.padding(16.dp)) {
                    Text(stringResource(R.string.today), fontWeight = FontWeight.Bold, fontSize = 18.sp)
                    Spacer(Modifier.height(8.dp))
                    LinearProgressIndicator(
                        progress = { stats.dailyGoalProgress.toFloat() },
                        modifier = Modifier.fillMaxWidth(),
                        color = if (stats.hasMetDailyGoal) successStrong() else accentStrong(),
                    )
                    Spacer(Modifier.height(8.dp))
                    Text(
                        stringResource(R.string.xp_of, stats.xpToday, stats.dailyGoalXp),
                        color = MaterialTheme.colorScheme.onSurfaceVariant,
                        fontSize = 13.sp,
                    )
                }
            }
        }

        // The honest ladder: exposure, then in the schedule, then mastery.
        // Kept as three separate figures exactly as on iOS, because conflating
        // them is the overstatement this app exists to avoid.
        item {
            Row(horizontalArrangement = Arrangement.spacedBy(12.dp)) {
                StatTile(stringResource(R.string.day_streak), stats.currentStreak, Modifier.weight(1f))
                StatTile(stringResource(R.string.total_xp), stats.totalXp, Modifier.weight(1f))
            }
        }
        item {
            Row(horizontalArrangement = Arrangement.spacedBy(12.dp)) {
                StatTile(stringResource(R.string.words_seen), stats.wordsSeen, Modifier.weight(1f))
                StatTile(stringResource(R.string.lessons_done), stats.lessonsCompleted, Modifier.weight(1f))
            }
        }
        item {
            Row(horizontalArrangement = Arrangement.spacedBy(12.dp)) {
                StatTile(stringResource(R.string.in_review), stats.wordsPracticed, Modifier.weight(1f))
                StatTile(stringResource(R.string.mastered), stats.wordsMastered, Modifier.weight(1f))
            }
        }

        // The goal is changeable, because onboarding promised it would be.
        item {
            Text(
                stringResource(R.string.daily_goal),
                fontWeight = FontWeight.Bold,
                fontSize = 18.sp,
                modifier = Modifier.padding(top = 8.dp),
            )
        }
        item {
            Card(Modifier.fillMaxWidth()) {
                Column(Modifier.padding(8.dp)) {
                    for (option in LearningGoal.entries) {
                        Row(
                            Modifier
                                .fillMaxWidth()
                                .clickable {
                                    progress.goal = option
                                    goal = option
                                    onChanged()
                                }
                                .padding(12.dp),
                            verticalAlignment = Alignment.CenterVertically,
                        ) {
                            RadioButton(selected = option == goal, onClick = null)
                            Spacer(Modifier.width(12.dp))
                            // One string, because the minutes and the XP are
                            // the same fact said two ways and a translator
                            // needs them together to order them naturally.
                            Text(
                                stringResource(
                                    R.string.minutes_and_xp,
                                    option.minutesPerDay,
                                    option.dailyXpGoal,
                                ),
                                modifier = Modifier.weight(1f),
                            )
                        }
                    }
                }
            }
        }

        item {
            Text(
                "${stringResource(R.string.achievements)}  ${unlocked.size}/${AchievementCatalog.all.size}",
                fontWeight = FontWeight.Bold,
                fontSize = 18.sp,
                modifier = Modifier.padding(top = 8.dp),
            )
        }
        items(AchievementCatalog.all, key = { it.id }) { achievement ->
            val isUnlocked = achievement.id in unlocked
            Card(Modifier.fillMaxWidth()) {
                Row(Modifier.padding(14.dp), verticalAlignment = Alignment.CenterVertically) {
                    Text(if (isUnlocked) "🏅" else "🔒", fontSize = 20.sp)
                    Spacer(Modifier.width(12.dp))
                    Column(Modifier.weight(1f)) {
                        Text(
                            AchievementStrings.title(achievement)
                                ?.let { stringResource(it) } ?: achievement.title,
                            fontWeight = FontWeight.SemiBold,
                            color = if (isUnlocked) MaterialTheme.colorScheme.onSurface
                            else MaterialTheme.colorScheme.onSurfaceVariant,
                        )
                        Text(
                            AchievementStrings.detail(achievement)
                                ?.let { stringResource(it) } ?: achievement.detail,
                            fontSize = 12.sp,
                            color = MaterialTheme.colorScheme.onSurfaceVariant,
                        )
                    }
                    if (!isUnlocked) {
                        Text(
                            "${achievement.progressValueIn(stats)}/${achievement.threshold}",
                            fontSize = 12.sp,
                            color = MaterialTheme.colorScheme.onSurfaceVariant,
                        )
                    }
                }
            }
        }
    }
}

@Composable
private fun StatTile(label: String, value: Int, modifier: Modifier = Modifier) {
    Card(modifier) {
        Column(
            Modifier.fillMaxWidth().padding(16.dp),
            horizontalAlignment = Alignment.CenterHorizontally,
        ) {
            Text(value.toString(), fontSize = 24.sp, fontWeight = FontWeight.Bold)
            Text(
                label,
                fontSize = 12.sp,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
                textAlign = TextAlign.Center,
            )
        }
    }
}
