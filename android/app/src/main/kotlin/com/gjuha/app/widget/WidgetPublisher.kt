package com.gjuha.app.widget

import android.content.Context
import android.util.Log
import androidx.glance.appwidget.updateAll
import com.gjuha.app.ContentRepository
import com.gjuha.app.ProgressRepository
import com.gjuha.core.WidgetSnapshot
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import java.time.LocalDate

/**
 * Keeps the widget's projection in step with the app.
 *
 * The widget computes nothing, so this is the only thing that makes it true.
 * It is called after every change to learner state rather than on a timer,
 * because a figure that updates half an hour late is a figure the learner has
 * already acted on.
 */
object WidgetPublisher {

    fun publish(
        context: Context,
        content: ContentRepository,
        progress: ProgressRepository,
        today: LocalDate = LocalDate.now(),
    ) {
        val stats = progress.stats(today)
        val completed = progress.completedLessonIds

        // The next lesson is the first unlocked one still unfinished. Null when
        // everything available is done, which the widget says plainly rather
        // than naming a lesson that does not exist.
        val next = content.lessons
            .sortedWith(compareBy({ it.unit }, { it.order }))
            .firstOrNull { lesson ->
                lesson.id !in completed &&
                    lesson.unlock.requiresLessonIds.all { it in completed }
            }

        val snapshot = WidgetSnapshot(
            currentStreak = stats.currentStreak,
            totalXp = stats.totalXp,
            dueReviewCount = progress.dueCount(today),
            wordsMastered = stats.wordsMastered,
            nextLessonTitle = next?.title,
            practicedToday = stats.xpToday > 0,
            xpToday = stats.xpToday,
            dailyGoalXp = stats.dailyGoalXp,
            generatedOn = today,
        )

        WidgetSnapshotStore(context).write(snapshot)

        // Glance updates are suspending; a failure here must not take the app
        // down, because a stale widget is a far smaller problem than a crash.
        CoroutineScope(Dispatchers.Default).launch {
            try {
                GjuhaWidget().updateAll(context.applicationContext)
            } catch (t: Throwable) {
                // Logged rather than swallowed. A stale widget is a far smaller
                // problem than a crash, but a silent catch here hid a real
                // failure once already.
                Log.w("GjuhaWidget", "widget update failed", t)
            }
        }
    }
}
