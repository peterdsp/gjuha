package com.gjuha.app.widget

import android.content.Context
import androidx.compose.runtime.Composable
import androidx.compose.ui.unit.dp
import androidx.glance.GlanceId
import androidx.glance.GlanceModifier
import androidx.glance.GlanceTheme
import androidx.glance.action.actionStartActivity
import androidx.glance.action.clickable
import androidx.glance.appwidget.GlanceAppWidget
import androidx.glance.appwidget.GlanceAppWidgetReceiver
import androidx.glance.appwidget.provideContent
import androidx.glance.background
import androidx.glance.layout.Alignment
import androidx.glance.layout.Column
import androidx.glance.layout.Row
import androidx.glance.layout.Spacer
import androidx.glance.layout.fillMaxSize
import androidx.glance.layout.fillMaxWidth
import androidx.glance.layout.height
import androidx.glance.layout.padding
import androidx.glance.text.FontWeight
import androidx.glance.text.Text
import androidx.glance.text.TextStyle
import androidx.glance.color.ColorProvider
import androidx.compose.ui.graphics.Color
import com.gjuha.app.MainActivity
import com.gjuha.app.ProgressRepository
import com.gjuha.core.WidgetSnapshot
import java.time.LocalDate

/**
 * The home screen widget.
 *
 * It answers one question at a glance: is there anything to do today? The
 * streak and the XP are context; the due count and the next lesson are the call
 * to action.
 *
 * It never computes anything. Every figure comes from the projection the app
 * writes, and a figure that only means something on the day it was computed is
 * withheld once that day has passed, rather than being shown stale. A learner
 * acts on "3 words due", so yesterday's 3 is worse than none.
 */
class GjuhaWidget : GlanceAppWidget() {

    override suspend fun provideGlance(context: Context, id: GlanceId) {
        val snapshot = WidgetSnapshotStore(context).read()
        provideContent {
            GlanceTheme {
                WidgetBody(snapshot, LocalDate.now())
            }
        }
    }
}

class GjuhaWidgetReceiver : GlanceAppWidgetReceiver() {
    override val glanceAppWidget: GlanceAppWidget = GjuhaWidget()
}

// The palette is duplicated here rather than imported from the app's Compose
// theme because Glance uses its own ColorProvider and cannot read a Material
// scheme. The values are the generated iOS ones.
private object W {
    val background = ColorProvider(day = Color(0xFFFFFFFF), night = Color(0xFF1E1E22))
    val text = ColorProvider(day = Color(0xFF1A1A1E), night = Color(0xFFF3F3F5))
    val secondary = ColorProvider(day = Color(0xFF66666B), night = Color(0xFF94949A))
    val accent = ColorProvider(day = Color(0xFFB8221C), night = Color(0xFFFF746B))
    val streak = ColorProvider(day = Color(0xFFAA4300), night = Color(0xFFFFA654))
    val success = ColorProvider(day = Color(0xFF0E7440), night = Color(0xFF66DE99))
}

@Composable
private fun WidgetBody(snapshot: WidgetSnapshot, today: LocalDate) {
    val q = snapshot.quotable(today)

    Column(
        modifier = GlanceModifier
            .fillMaxSize()
            .background(W.background)
            .padding(12.dp)
            .clickable(actionStartActivity<MainActivity>()),
        verticalAlignment = Alignment.Top,
    ) {
        if (!snapshot.isRealData) {
            // Never written is not the same as nothing to do, so the widget
            // invites a first lesson instead of reporting a zero streak.
            Text("Gjuha", style = TextStyle(color = W.text, fontWeight = FontWeight.Bold))
            Spacer(GlanceModifier.height(4.dp))
            Text(
                "Open to start learning Albanian.",
                style = TextStyle(color = W.secondary, fontSize = 12.sp()),
            )
            return@Column
        }

        Row(modifier = GlanceModifier.fillMaxWidth()) {
            Text(
                "🔥 ${q.currentStreak}",
                style = TextStyle(color = W.streak, fontWeight = FontWeight.Bold),
            )
            Spacer(GlanceModifier.defaultWeight())
            Text("⭐ ${q.totalXp}", style = TextStyle(color = W.text))
        }

        Spacer(GlanceModifier.height(8.dp))

        // Today's figures appear only while they are still today's.
        val xpToday = q.xpToday
        val goal = q.dailyGoalXp
        if (xpToday != null && goal != null && goal > 0) {
            val met = xpToday >= goal
            Text(
                "$xpToday/$goal XP",
                style = TextStyle(
                    color = if (met) W.success else W.text,
                    fontWeight = FontWeight.Medium,
                ),
            )
        } else {
            Text(
                "Open to see today",
                style = TextStyle(color = W.secondary, fontSize = 12.sp()),
            )
        }

        Spacer(GlanceModifier.height(6.dp))

        // The due count and "done for today" are day-sensitive, so they drop out
        // once the projection is stale. The next lesson is not: which lesson
        // comes next does not change at midnight, so it still shows and the
        // widget keeps saying something useful rather than going half blank.
        val due = q.dueReviewCount
        when {
            due != null && due > 0 -> Text(
                if (due == 1) "1 word to review" else "$due words to review",
                style = TextStyle(color = W.accent, fontWeight = FontWeight.Medium),
            )
            due != null && q.practicedToday == true -> Text(
                "Done for today",
                style = TextStyle(color = W.success),
            )
            else -> q.nextLessonTitle?.let {
                Text("Next: $it", style = TextStyle(color = W.secondary, fontSize = 12.sp()))
            }
        }
    }
}

/** Glance styles take sp, and the import collides with Compose's own. */
private fun Int.sp() = androidx.compose.ui.unit.TextUnit(
    this.toFloat(),
    androidx.compose.ui.unit.TextUnitType.Sp,
)
