package com.gjuha.app.widget

import android.content.Context
import com.gjuha.core.WidgetSnapshot
import java.time.LocalDate

/**
 * Stores the projection the widget renders.
 *
 * Reading is defensive in the same way as the other stores: a missing or
 * unparseable value yields the placeholder rather than throwing, so a format
 * change degrades to "open to start" instead of a crashed widget.
 */
class WidgetSnapshotStore(context: Context) {

    private val prefs =
        context.applicationContext.getSharedPreferences("gjuha.widget", Context.MODE_PRIVATE)

    fun read(): WidgetSnapshot = runCatching {
        val day = prefs.getString(KEY_DAY, null) ?: return WidgetSnapshot()
        WidgetSnapshot(
            currentStreak = prefs.getInt(KEY_STREAK, 0),
            totalXp = prefs.getInt(KEY_TOTAL_XP, 0),
            dueReviewCount = prefs.getInt(KEY_DUE, 0),
            wordsMastered = prefs.getInt(KEY_MASTERED, 0),
            nextLessonTitle = prefs.getString(KEY_NEXT, null),
            practicedToday = prefs.getBoolean(KEY_PRACTICED, false),
            xpToday = prefs.getInt(KEY_XP_TODAY, 0),
            dailyGoalXp = prefs.getInt(KEY_GOAL, 0),
            generatedOn = LocalDate.parse(day),
        )
    }.getOrElse { WidgetSnapshot() }

    fun write(snapshot: WidgetSnapshot) {
        prefs.edit()
            .putInt(KEY_STREAK, snapshot.currentStreak)
            .putInt(KEY_TOTAL_XP, snapshot.totalXp)
            .putInt(KEY_DUE, snapshot.dueReviewCount)
            .putInt(KEY_MASTERED, snapshot.wordsMastered)
            .putString(KEY_NEXT, snapshot.nextLessonTitle)
            .putBoolean(KEY_PRACTICED, snapshot.practicedToday)
            .putInt(KEY_XP_TODAY, snapshot.xpToday)
            .putInt(KEY_GOAL, snapshot.dailyGoalXp)
            .putString(KEY_DAY, snapshot.generatedOn?.toString())
            .apply()
    }

    private companion object {
        const val KEY_STREAK = "streak"
        const val KEY_TOTAL_XP = "totalXp"
        const val KEY_DUE = "due"
        const val KEY_MASTERED = "mastered"
        const val KEY_NEXT = "nextLesson"
        const val KEY_PRACTICED = "practicedToday"
        const val KEY_XP_TODAY = "xpToday"
        const val KEY_GOAL = "dailyGoalXp"
        const val KEY_DAY = "generatedOn"
    }
}
