import AppIntents
import SwiftUI

// Gjuha's App Intents surface.
//
// Four intents, deliberately. The build caps an app at ten App Shortcuts, and
// Siri matches a small focused set far better than a long one, so these cover the
// things a learner actually asks for out loud and nothing else.
//
// Contract note: an intent's type name, and each `AppShortcut` phrase, are a
// published contract. Saved shortcuts replay the intent by type name; installed
// voice triggers match the phrase. Adding is safe. Renaming or removing either
// breaks something already on a learner's device, so do not do it silently.
//
// None of these fabricates progress. Nothing here can mark a lesson complete or
// bank XP: the only way to earn either is to answer questions in the app.
//
// On execution target: none of these declares `allowedExecutionTargets`. The app
// ships no App Intents extension, so the system already runs them in the main app
// process, and Apple's guidance is to prefer the default unless the code genuinely
// needs a specific process, because pinning to `.main` defeats extension based
// execution and adds launch latency. It was also the only iOS 27 only API in the
// project, and dropping it is what lets the deployment target sit at iOS 26 where
// CI can actually build and test.

// MARK: - Start review

/// Starts a spaced repetition session over whatever is due right now.
///
/// Runs in the background first so that "nothing is due" can be answered without
/// yanking the learner into the app, and escalates to the foreground only when
/// there is actually a session to run. That is the whole reason for the
/// `[.background, .foreground(.dynamic)]` pairing.
struct StartReviewIntent: AppIntent {
    static let title: LocalizedStringResource = "Start Albanian Review"
    static let description = IntentDescription(
        "Reviews the Albanian words that are due today, using Gjuha's spaced repetition schedule.",
        categoryName: "Practice"
    )

    static var supportedModes: IntentModes { [.background, .foreground(.dynamic)] }

    func perform() async throws -> some IntentResult & ProvidesDialog {
        let dueCount = await LiveReviewRepository().dueCount()

        guard dueCount > 0 else {
            // Honest answer, and no reason to open the app for it.
            return .result(dialog: "Nothing is due for review right now. Nice work.")
        }

        guard systemContext.currentMode.canContinueInForeground else {
            // A voice-only or otherwise non-foregroundable surface. Tell the
            // system we need the app so it can offer to open it, rather than
            // silently doing nothing.
            throw needsToContinueInForegroundError("Open Gjuha to review \(dueCount) words")
        }

        try await continueInForeground(alwaysConfirm: false)

        // Routing is the only side effect, and it happens last: App Intents may
        // retry `perform()` from the top, and starting the session twice would be
        // visible to the learner.
        await GjuhaIntentRouter.route(.startReview)

        return .result(dialog: "Starting your review of \(dueCount) words.")
    }
}

// MARK: - Continue learning

/// Opens the lesson the learner is in the middle of, or the next one they can
/// start. Always needs the app, so it is foreground-only.
struct ContinueLearningIntent: AppIntent {
    static let title: LocalizedStringResource = "Continue Albanian Lesson"
    static let description = IntentDescription(
        "Picks up the Albanian lesson in progress, or opens the next lesson available.",
        categoryName: "Practice"
    )

    static var supportedModes: IntentModes { .foreground(.immediate) }

    func perform() async throws -> some IntentResult {
        await GjuhaIntentRouter.route(.continueLearning)
        return .result()
    }
}

// MARK: - Check progress

/// Reports the learner's streak and what is due, without opening the app.
///
/// Every figure here is read from the same stores the Profile screen reads, and
/// "mastered" means the scheduler's documented mastery interval, not a count of
/// words seen. The snippet must stay side-effect free: the system may re-run the
/// intent to redraw the card.
struct CheckProgressIntent: AppIntent {
    static let title: LocalizedStringResource = "Check Albanian Progress"
    static let description = IntentDescription(
        "Reports your Gjuha streak, the words due for review, and how many words you have mastered.",
        categoryName: "Progress"
    )

    static var supportedModes: IntentModes { .background }

    func perform() async throws -> some IntentResult & ProvidesDialog & ShowsSnippetView {
        let progress = ProgressStore.shared
        let retention = await LiveReviewRepository().summary()

        let streak = progress.currentStreak
        let due = retention.dueCount

        let dialog: IntentDialog = if streak == 0 {
            "You have not started a streak yet. \(due) words are due for review."
        } else if due == 0 {
            "You are on a \(streak) day streak, and nothing is due for review."
        } else {
            "You are on a \(streak) day streak, with \(due) words due for review."
        }

        return .result(
            dialog: dialog,
            view: ProgressSnippetView(
                streak: streak,
                totalXP: progress.totalXP,
                dueCount: due,
                wordsMastered: retention.wordsMastered
            )
        )
    }
}

// MARK: - Open progress

/// Opens the Profile tab, where the honest breakdown of seen / in review /
/// mastered lives.
struct OpenProgressIntent: AppIntent {
    static let title: LocalizedStringResource = "Open Albanian Progress"
    static let description = IntentDescription(
        "Opens your Gjuha progress, including words seen, words in review, and words mastered.",
        categoryName: "Progress"
    )

    static var supportedModes: IntentModes { .foreground(.immediate) }

    func perform() async throws -> some IntentResult {
        await GjuhaIntentRouter.route(.progress)
        return .result()
    }
}

// MARK: - App Shortcuts

/// The zero-setup voice and Spotlight entry points.
///
/// Every phrase interpolates `\(.applicationName)`: without it Xcode warns and the
/// runtime index silently drops the phrase, so the utterance would never work.
struct GjuhaShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: StartReviewIntent(),
            phrases: [
                "Start my review in \(.applicationName)",
                "Review Albanian with \(.applicationName)",
                "Practice Albanian in \(.applicationName)"
            ],
            shortTitle: "Start Review",
            systemImageName: "arrow.triangle.2.circlepath"
        )

        AppShortcut(
            intent: ContinueLearningIntent(),
            phrases: [
                "Continue my lesson in \(.applicationName)",
                "Keep learning Albanian in \(.applicationName)"
            ],
            shortTitle: "Continue Lesson",
            systemImageName: "bolt.fill"
        )

        AppShortcut(
            intent: CheckProgressIntent(),
            phrases: [
                "What is my streak in \(.applicationName)",
                "How is my Albanian going in \(.applicationName)"
            ],
            shortTitle: "Check Progress",
            systemImageName: "chart.line.uptrend.xyaxis"
        )

        AppShortcut(
            intent: OpenProgressIntent(),
            phrases: [
                "Open my progress in \(.applicationName)"
            ],
            shortTitle: "Open Progress",
            systemImageName: "person.crop.circle.fill"
        )
    }
}
