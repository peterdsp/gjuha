import Foundation

/// The App Group shared by the app and its widget extension.
///
/// Enabling App Groups is a signing capability, so a build whose provisioning
/// profile lacks it will not get a shared container. Everything below treats that
/// as a normal, survivable condition rather than an error: the widget shows its
/// placeholder and the app is unaffected, because no canonical learner data lives
/// here.
enum GjuhaAppGroup {
    static let identifier = "group.com.gjuha.app"
}

/// A small, derived, read-only view of the learner's state, written by the app for
/// the widget to render.
///
/// This is deliberately a *projection*, not a store. The canonical data stays
/// where it already lives (`ProgressStore`, `ReviewStore`, `LessonSessionStore`,
/// all in `UserDefaults.standard`, inside the app container). Nothing reads this
/// snapshot back into the app, and losing it loses nothing: the next refresh
/// rebuilds it from the canonical stores.
///
/// Keeping it a projection is the point. Moving the real stores into the App Group
/// suite would make a signing misconfiguration silently stop persisting a
/// learner's progress, which is a far worse failure than a stale widget.
struct GjuhaWidgetSnapshot: Codable, Equatable, Sendable {
    /// Consecutive days with study activity, as `ProgressStore` counts it.
    var currentStreak: Int
    /// Lifetime XP.
    var totalXP: Int
    /// Words the spaced repetition scheduler says are due right now.
    var dueReviewCount: Int
    /// Words that have climbed to the scheduler's documented mastery interval.
    /// This is the same honest figure the Profile screen shows, never an estimate.
    var wordsMastered: Int
    /// Title of the next unlocked, incomplete lesson, or nil when there is none
    /// (everything available is done).
    var nextLessonTitle: String?
    /// Whether the learner has already studied today, so the widget can say
    /// "done for today" instead of nagging.
    var practicedToday: Bool
    /// XP earned since local midnight, and the goal it is measured against.
    /// Both are day-sensitive, so `isStale(on:)` governs whether they may be
    /// quoted, exactly as it does for `dueReviewCount` and `practicedToday`.
    var xpToday: Int
    /// XP that meets the learner's chosen daily goal.
    var dailyGoalXP: Int
    /// When this projection was built, used for the widget's staleness handling.
    var generatedAt: Date

    /// Today's progress toward the goal, clamped to 0...1 for a ring or gauge.
    var dailyGoalProgress: Double {
        guard dailyGoalXP > 0 else { return 0 }
        return min(1.0, Double(xpToday) / Double(dailyGoalXP))
    }

    var hasMetDailyGoal: Bool { dailyGoalXP > 0 && xpToday >= dailyGoalXP }

    init(
        currentStreak: Int,
        totalXP: Int,
        dueReviewCount: Int,
        wordsMastered: Int,
        nextLessonTitle: String?,
        practicedToday: Bool,
        xpToday: Int = 0,
        dailyGoalXP: Int = 0,
        generatedAt: Date
    ) {
        self.currentStreak = currentStreak
        self.totalXP = totalXP
        self.dueReviewCount = dueReviewCount
        self.wordsMastered = wordsMastered
        self.nextLessonTitle = nextLessonTitle
        self.practicedToday = practicedToday
        self.xpToday = xpToday
        self.dailyGoalXP = dailyGoalXP
        self.generatedAt = generatedAt
    }

    /// Decoding is written out so `xpToday` and `dailyGoalXP`, added after the
    /// `v1` key was already in the field, default to zero rather than throwing.
    ///
    /// Synthesised `Codable` would reject a payload written by the previous
    /// version, and an installed widget would fall back to its placeholder until
    /// the learner next opened the app. Defaulting means the widget keeps showing
    /// a correct streak and due count through the update, and simply omits the
    /// goal ring (`dailyGoalXP == 0`) until the app writes a fresh projection.
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        currentStreak = try container.decode(Int.self, forKey: .currentStreak)
        totalXP = try container.decode(Int.self, forKey: .totalXP)
        dueReviewCount = try container.decode(Int.self, forKey: .dueReviewCount)
        wordsMastered = try container.decode(Int.self, forKey: .wordsMastered)
        nextLessonTitle = try container.decodeIfPresent(String.self, forKey: .nextLessonTitle)
        practicedToday = try container.decode(Bool.self, forKey: .practicedToday)
        xpToday = try container.decodeIfPresent(Int.self, forKey: .xpToday) ?? 0
        dailyGoalXP = try container.decodeIfPresent(Int.self, forKey: .dailyGoalXP) ?? 0
        generatedAt = try container.decode(Date.self, forKey: .generatedAt)
    }

    /// What the widget shows before the app has ever written a snapshot, and in
    /// the widget gallery preview. Deliberately all zeroes with no fabricated
    /// streak or XP.
    static let placeholder = GjuhaWidgetSnapshot(
        currentStreak: 0,
        totalXP: 0,
        dueReviewCount: 0,
        wordsMastered: 0,
        nextLessonTitle: nil,
        practicedToday: false,
        xpToday: 0,
        dailyGoalXP: 0,
        generatedAt: .distantPast
    )

    /// A representative snapshot for the widget gallery, where showing zeroes
    /// would make the widget look broken. Only ever used for gallery previews,
    /// never on a real home screen.
    static let gallerySample = GjuhaWidgetSnapshot(
        currentStreak: 12,
        totalXP: 1_480,
        dueReviewCount: 9,
        wordsMastered: 34,
        nextLessonTitle: "Coffee & ordering",
        practicedToday: false,
        xpToday: 80,
        dailyGoalXP: 120,
        generatedAt: Date()
    )

    /// True when the app has actually written this snapshot, as opposed to the
    /// widget falling back to `placeholder`.
    var isRealData: Bool { generatedAt != .distantPast }

    /// Whether the day-sensitive counts in this snapshot can still be trusted at
    /// `date`.
    ///
    /// `dueReviewCount` and `practicedToday` are both relative to a calendar day:
    /// more words fall due at midnight and "practised today" resets. The widget
    /// cannot recompute either, because the review schedule deliberately stays in
    /// the app container, so once the day has turned it must stop quoting numbers
    /// rather than show a figure that is probably wrong.
    ///
    /// A placeholder is never "stale": it has no numbers to be wrong about.
    func isStale(on date: Date, calendar: Calendar = .current) -> Bool {
        guard isRealData else { return false }
        return !calendar.isDate(generatedAt, inSameDayAs: date)
    }
}

/// Reads and writes `GjuhaWidgetSnapshot` in the App Group container.
///
/// Decoding is defensive in the same way as the other Gjuha stores: a missing,
/// empty, or corrupt value yields nil rather than a crash, so a format change or a
/// half written value degrades to the placeholder.
final class WidgetSnapshotStore: @unchecked Sendable {
    static let shared = WidgetSnapshotStore()

    private let key = "gjuha.widgetSnapshot.v1"
    private let defaults: UserDefaults?

    /// `UserDefaults(suiteName:)` is nil only for an invalid suite name, but an
    /// unentitled App Group still fails to share. Either way the snapshot simply
    /// does not reach the widget, which then renders its placeholder.
    init(defaults: UserDefaults? = UserDefaults(suiteName: GjuhaAppGroup.identifier)) {
        self.defaults = defaults
    }

    func load() -> GjuhaWidgetSnapshot? {
        guard let defaults, let data = defaults.data(forKey: key), !data.isEmpty else { return nil }
        return try? JSONDecoder().decode(GjuhaWidgetSnapshot.self, from: data)
    }

    func write(_ snapshot: GjuhaWidgetSnapshot) {
        guard let defaults, let data = try? JSONEncoder().encode(snapshot) else { return }
        defaults.set(data, forKey: key)
    }

    /// Clears the projection. Called when the learner resets their data, so the
    /// widget does not keep showing a streak that no longer exists.
    func clear() {
        defaults?.removeObject(forKey: key)
    }
}
