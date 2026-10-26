#if DEBUG
import Foundation

/// Launch-argument hooks that exist only for automated UI tests.
///
/// This is ISOLATED TEST SCAFFOLDING, in the same spirit as the existing
/// `-GjuhaCultureFixtures` hook: it is compiled only into DEBUG builds and does
/// nothing unless the app is launched with the explicit argument. A release build
/// does not contain this file at all, so there is no path by which a learner's
/// data can be wiped by it.
enum UITestSupport {
    /// Wipes local state so a UI test starts from a known first-launch position.
    static let resetArgument = "-GjuhaResetStateForUITests"

    static var isResetRequested: Bool {
        CommandLine.arguments.contains(resetArgument)
    }

    /// Clears onboarding, progress, the review schedule, any saved lesson, and
    /// the reminder settings.
    ///
    /// Must run before anything reads `UserDefaults`, which is why it is called
    /// from `GjuhaApp.init()`: `AppFeature.State` reads the onboarding flag the
    /// first time the store is touched, which happens later, in the scene body.
    static func resetStateIfRequested() {
        guard isResetRequested else { return }

        let defaults = UserDefaults.standard
        // Every key the app owns, named rather than wildcarded so this stays
        // honest about its blast radius.
        let keys = [
            "hasCompletedOnboarding",
            "gjuha.completedLessonSeedIds",
            "gjuha.xpByLesson",
            "gjuha.totalXP",
            "gjuha.currentStreak",
            "gjuha.lastActivityDate",
            "gjuha.learningGoal",
            "gjuha.reviewSchedule.v1",
            "gjuha.lessonSession.v1"
        ]
        keys.forEach { defaults.removeObject(forKey: $0) }
        defaults.synchronize()

        // The widget projection lives in the App Group, not standard defaults.
        WidgetSnapshotStore.shared.clear()
    }
}
#endif
