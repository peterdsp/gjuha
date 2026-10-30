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
import androidx.compose.ui.draw.clip
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.gjuha.core.AchievementCatalog
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

private enum class Screen { LEARN, PROFILE }

@Composable
private fun GjuhaApp(content: ContentRepository, progress: ProgressRepository) {
    var screen by remember { mutableStateOf(Screen.LEARN) }
    var openLesson by remember { mutableStateOf<SeedLesson?>(null) }
    var inReview by remember { mutableStateOf(false) }
    var onboarded by remember { mutableStateOf(progress.hasCompletedOnboarding) }
    // Bumped whenever progress changes, so the screens re-read their figures.
    var revision by remember { mutableIntStateOf(0) }

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
                // unlocks nothing: the words were rescheduled as they were
                // answered.
                progress.recordReviewActivity(xp)
                progress.recordUnlocks()
                revision++
                inReview = false
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
            onFinished = { xp, wordIds ->
                progress.completeLesson(lesson.id, xp, wordIds)
                progress.recordUnlocks()
                revision++
                openLesson = null
            },
            onQuit = { openLesson = null },
        )
        return
    }

    Scaffold(
        bottomBar = {
            NavigationBar {
                NavigationBarItem(
                    selected = screen == Screen.LEARN,
                    onClick = { screen = Screen.LEARN },
                    label = { Text("Learn") },
                    icon = { Text("⚡", fontSize = 18.sp) },
                )
                NavigationBarItem(
                    selected = screen == Screen.PROFILE,
                    onClick = { screen = Screen.PROFILE },
                    label = { Text("Profile") },
                    icon = { Text("👤", fontSize = 18.sp) },
                )
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
                Screen.PROFILE -> ProfileScreen(progress, stats)
            }
        }
    }
}

// MARK: - Learn

@Composable
private fun LearnScreen(
    content: ContentRepository,
    stats: UserStats,
    completed: Set<String>,
    dueCount: Int,
    onStartReview: () -> Unit,
    onOpen: (SeedLesson) -> Unit,
) {
    val unit = remember { content.units.minByOrNull { it.unit } }
    val lessons = remember(unit) { unit?.let { content.lessons(it) }.orEmpty() }

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

        item {
            unit?.let {
                Card(Modifier.fillMaxWidth()) {
                    Column(Modifier.padding(16.dp)) {
                        Text(
                            "Unit ${it.unit} - ${it.title}",
                            fontSize = 20.sp,
                            fontWeight = FontWeight.Bold,
                        )
                        Spacer(Modifier.height(4.dp))
                        val done = lessons.count { l -> l.id in completed }
                        Text(
                            "$done/${lessons.size} lessons",
                            color = MaterialTheme.colorScheme.onSurfaceVariant,
                            fontSize = 13.sp,
                        )
                        Spacer(Modifier.height(8.dp))
                        LinearProgressIndicator(
                            progress = {
                                if (lessons.isEmpty()) 0f else done.toFloat() / lessons.size
                            },
                            modifier = Modifier.fillMaxWidth(),
                        )
                    }
                }
            }
        }

        items(lessons, key = { it.id }) { lesson ->
            val isDone = lesson.id in completed
            // A lesson opens once everything it requires is finished. The rule
            // comes from the seed, not from a hardcoded index.
            val isLocked = lesson.unlock.requiresLessonIds.any { it !in completed }
            LessonRow(lesson, isDone, isLocked) { if (!isLocked) onOpen(lesson) }
        }
    }
}

@Composable
private fun ReviewCard(dueCount: Int, onStart: () -> Unit) {
    Card(
        onClick = onStart,
        modifier = Modifier.fillMaxWidth(),
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
                    "Review",
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
            Metric("🔥", stats.currentStreak.toString(), streakStrong())
            Column(horizontalAlignment = Alignment.CenterHorizontally) {
                Text("Today", fontSize = 12.sp, color = MaterialTheme.colorScheme.onSurfaceVariant)
                Text(
                    "${stats.xpToday}/${stats.dailyGoalXp} XP",
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
            Metric("⭐", stats.totalXp.toString(), xpStrong())
        }
    }
}

@Composable
private fun Metric(glyph: String, value: String, tint: androidx.compose.ui.graphics.Color) {
    Row(verticalAlignment = Alignment.CenterVertically) {
        Text(glyph, fontSize = 16.sp)
        Spacer(Modifier.width(4.dp))
        Text(value, color = tint, fontWeight = FontWeight.Bold)
    }
}

@Composable
private fun LessonRow(lesson: SeedLesson, isDone: Boolean, isLocked: Boolean, onClick: () -> Unit) {
    Card(
        Modifier.fillMaxWidth().clickable(enabled = !isLocked, onClick = onClick),
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
private fun ProfileScreen(progress: ProgressRepository, stats: UserStats) {
    val unlocked = remember(stats) { progress.unlockedAchievementIds() }

    LazyColumn(
        modifier = Modifier.fillMaxSize(),
        contentPadding = PaddingValues(16.dp),
        verticalArrangement = Arrangement.spacedBy(12.dp),
    ) {
        item {
            Card(Modifier.fillMaxWidth()) {
                Column(Modifier.padding(16.dp)) {
                    Text("Today", fontWeight = FontWeight.Bold, fontSize = 18.sp)
                    Spacer(Modifier.height(8.dp))
                    LinearProgressIndicator(
                        progress = { stats.dailyGoalProgress.toFloat() },
                        modifier = Modifier.fillMaxWidth(),
                        color = if (stats.hasMetDailyGoal) successStrong() else accentStrong(),
                    )
                    Spacer(Modifier.height(8.dp))
                    Text(
                        "${stats.xpToday}/${stats.dailyGoalXp} XP",
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
                StatTile("Day streak", stats.currentStreak, Modifier.weight(1f))
                StatTile("Total XP", stats.totalXp, Modifier.weight(1f))
            }
        }
        item {
            Row(horizontalArrangement = Arrangement.spacedBy(12.dp)) {
                StatTile("Words seen", stats.wordsSeen, Modifier.weight(1f))
                StatTile("Lessons done", stats.lessonsCompleted, Modifier.weight(1f))
            }
        }
        item {
            Row(horizontalArrangement = Arrangement.spacedBy(12.dp)) {
                StatTile("In review", stats.wordsPracticed, Modifier.weight(1f))
                StatTile("Mastered", stats.wordsMastered, Modifier.weight(1f))
            }
        }

        item {
            Text(
                "Achievements  ${unlocked.size}/${AchievementCatalog.all.size}",
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
                            achievement.title,
                            fontWeight = FontWeight.SemiBold,
                            color = if (isUnlocked) MaterialTheme.colorScheme.onSurface
                            else MaterialTheme.colorScheme.onSurfaceVariant,
                        )
                        Text(
                            achievement.detail,
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
