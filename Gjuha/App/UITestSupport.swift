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

    /// Clears onboarding, progress, the review schedule, any saved lesson, the
    /// achievement ledger and the reminder settings.
    ///
    /// Must run before anything reads `UserDefaults`, which is why it is called
    /// from `GjuhaApp.init()`: `AppFeature.State` reads the onboarding flag the
    /// first time the store is touched, which happens later, in the scene body.
    ///
    /// **Delegates to the stores rather than listing their keys.** It used to
    /// name every key by hand, with a comment claiming the list was complete.
    /// That claim quietly stopped being true: the daily XP keys and the
    /// achievement ledger were added later and never reached the list, so a UI
    /// test "starting from a known first-launch position" actually started with
    /// the previous run's XP and badges. It showed up as a Profile screen
    /// reporting 97 XP earned today, zero lessons completed, and an unlocked
    /// achievement, all at once.
    ///
    /// A store knows its own keys, so asking each one to reset cannot go stale
    /// the way a copied list does. Only the few values that have no store of
    /// their own are named here.
    static func resetStateIfRequested() {
        guard isResetRequested else { return }

        ProgressStore.shared.resetLearningProgress()
        AchievementStore.shared.reset()
        ReviewStore.shared.reset()
        LessonSessionStore.shared.clear()

        let defaults = UserDefaults.standard
        // No store owns these three. `resetLearningProgress` deliberately keeps
        // the chosen goal, because a learner resetting their progress has not
        // asked to be re-onboarded; a UI test has.
        [
            "hasCompletedOnboarding",
            "gjuha.learningGoal",
            "gjuha.reminderSettings.v1"
        ].forEach { defaults.removeObject(forKey: $0) }
        defaults.synchronize()

        // The widget projection lives in the App Group, not standard defaults.
        WidgetSnapshotStore.shared.clear()
    }
}
#endif
