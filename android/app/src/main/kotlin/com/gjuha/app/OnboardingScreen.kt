package com.gjuha.app

import androidx.compose.foundation.layout.*
import androidx.compose.foundation.rememberScrollState
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
import com.gjuha.core.LearningGoal

/**
 * First run.
 *
 * Its one job is to let the learner pick a daily goal, because the goal is the
 * only setting the app cannot sensibly guess and the only one a learner is
 * punished for getting wrong: too high and the streak breaks, too low and the
 * ring stops meaning anything.
 *
 * Until this existed the goal silently defaulted to Casual, so the daily target
 * said 60 XP while iOS, whose onboarding asks, said 120 for the same learner.
 */
@Composable
fun OnboardingScreen(initial: LearningGoal, onFinished: (LearningGoal) -> Unit) {
    var selected by remember { mutableStateOf(initial) }

    Column(
        Modifier
            .fillMaxSize()
            .verticalScroll(rememberScrollState())
            .padding(24.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
    ) {
        Spacer(Modifier.height(48.dp))
        Text("🇦🇱", fontSize = 56.sp)
        Spacer(Modifier.height(16.dp))
        Text(
            "Mirësevini!",
            fontSize = 30.sp,
            fontWeight = FontWeight.Bold,
            textAlign = TextAlign.Center,
        )
        Spacer(Modifier.height(8.dp))
        Text(
            stringResource(R.string.tagline),
            color = MaterialTheme.colorScheme.onSurfaceVariant,
            textAlign = TextAlign.Center,
        )

        Spacer(Modifier.height(40.dp))
        Text(
            stringResource(R.string.set_daily_goal),
            fontSize = 18.sp,
            fontWeight = FontWeight.SemiBold,
        )
        Spacer(Modifier.height(4.dp))
        // Said plainly, because a goal picked without knowing what it costs is
        // the one that breaks a streak in week two.
        Text(
            "You can change this later.",
            fontSize = 13.sp,
            color = MaterialTheme.colorScheme.onSurfaceVariant,
        )
        Spacer(Modifier.height(16.dp))

        for (goal in LearningGoal.entries) {
            GoalRow(
                goal = goal,
                isSelected = goal == selected,
                onSelect = { selected = goal },
            )
            Spacer(Modifier.height(10.dp))
        }

        Spacer(Modifier.height(24.dp))
        Button(
            onClick = { onFinished(selected) },
            modifier = Modifier.fillMaxWidth().heightIn(min = 52.dp),
        ) {
Text(stringResource(R.string.start_learning), fontSize = 16.sp, fontWeight = FontWeight.SemiBold)
        }
        Spacer(Modifier.height(32.dp))
    }
}

@Composable
private fun GoalRow(goal: LearningGoal, isSelected: Boolean, onSelect: () -> Unit) {
    Card(
        onClick = onSelect,
        modifier = Modifier.fillMaxWidth(),
        colors = CardDefaults.cardColors(
            containerColor = if (isSelected) {
                MaterialTheme.colorScheme.primary
            } else {
                MaterialTheme.colorScheme.surface
            },
        ),
    ) {
        Row(
            Modifier.fillMaxWidth().padding(16.dp),
            verticalAlignment = Alignment.CenterVertically,
        ) {
            Column(Modifier.weight(1f)) {
                Text(
                    goal.label,
                    fontWeight = FontWeight.SemiBold,
                    color = if (isSelected) GjuhaColors.OnAccent else MaterialTheme.colorScheme.onSurface,
                )
                Text(
                    stringResource(R.string.minutes_and_xp, goal.minutesPerDay, goal.dailyXpGoal),
                    fontSize = 13.sp,
                    color = if (isSelected) {
                        GjuhaColors.OnAccent
                    } else {
                        MaterialTheme.colorScheme.onSurfaceVariant
                    },
                )
            }
            if (isSelected) Text("✓", color = GjuhaColors.OnAccent, fontSize = 20.sp)
        }
    }
}

/** Learner-facing names, matching the iOS wording. */
private val LearningGoal.label: String
    get() = when (this) {
        LearningGoal.CASUAL -> "Casual"
        LearningGoal.REGULAR -> "Regular"
        LearningGoal.SERIOUS -> "Serious"
        LearningGoal.INTENSE -> "Intense"
    }
