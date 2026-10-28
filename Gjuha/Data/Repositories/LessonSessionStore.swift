import Foundation

/// A durable snapshot of an in-progress course lesson, enough to put the learner
/// back exactly where they were after the app is terminated and relaunched.
///
/// Only course lessons are snapshotted. A spaced repetition review is never
/// stored here: a review records each outcome to the schedule as it is answered,
/// so there is nothing mid-session to restore.
struct LessonSessionSnapshot: Codable, Equatable {
    /// The lesson being taken, including its stable `seedId` and exercise plan.
    var lesson: LessonSummary
    /// The exact generated exercise sequence. Persisting the sequence (rather than
    /// regenerating on resume) keeps the questions and their option order stable,
    /// since generation shuffles options and picks distractors non-deterministically.
    var exercises: [Exercise]
    /// The question the learner is on.
    var currentIndex: Int
    /// Hearts remaining in this attempt.
    var hearts: Int
    /// XP accumulated so far this attempt. This is an in-memory accumulator only;
    /// it is banked into the lifetime total exactly once, on completion, so
    /// restoring it never double counts XP.
    var xpEarned: Int
    /// Current correct-answer combo.
    var combo: Int
    /// Answers graded so far this attempt, and how many were correct. Drive the
    /// accuracy figure on the completion screen.
    var answeredCount: Int
    var correctCount: Int
    /// When the snapshot was written, for diagnostics.
    var savedAt: Date

    init(
        lesson: LessonSummary,
        exercises: [Exercise],
        currentIndex: Int,
        hearts: Int,
        xpEarned: Int,
        combo: Int,
        answeredCount: Int = 0,
        correctCount: Int = 0,
        savedAt: Date
    ) {
        self.lesson = lesson
        self.exercises = exercises
        self.currentIndex = currentIndex
        self.hearts = hearts
        self.xpEarned = xpEarned
        self.combo = combo
        self.answeredCount = answeredCount
        self.correctCount = correctCount
        self.savedAt = savedAt
    }

    /// Decoding is written out rather than synthesised so that `answeredCount`
    /// and `correctCount`, added after 1.0 was already installable, default to
    /// zero when they are absent.
    ///
    /// Synthesised `Codable` would throw on a payload written by the previous
    /// version, `load()` would see nil, and a learner who updated the app
    /// mid-lesson would silently lose their place. Defaulting instead costs
    /// them an accuracy percentage on one completion screen, which is the right
    /// side of that trade.
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        lesson = try container.decode(LessonSummary.self, forKey: .lesson)
        exercises = try container.decode([Exercise].self, forKey: .exercises)
        currentIndex = try container.decode(Int.self, forKey: .currentIndex)
        hearts = try container.decode(Int.self, forKey: .hearts)
        xpEarned = try container.decode(Int.self, forKey: .xpEarned)
        combo = try container.decode(Int.self, forKey: .combo)
        answeredCount = try container.decodeIfPresent(Int.self, forKey: .answeredCount) ?? 0
        correctCount = try container.decodeIfPresent(Int.self, forKey: .correctCount) ?? 0
        savedAt = try container.decode(Date.self, forKey: .savedAt)
    }
}

/// UserDefaults backed persistence for the single in-progress course lesson,
/// mirroring `ProgressStore` and `ReviewStore`.
///
/// There is at most one saved session at a time: starting or resuming a lesson
/// overwrites it, and completing, failing, discarding, or resetting clears it.
/// Decoding is defensive: missing or corrupt data yields `nil` (no session to
/// resume) rather than crashing.
final class LessonSessionStore: @unchecked Sendable {
    static let shared = LessonSessionStore()

    private let defaults: UserDefaults
    private let key = "gjuha.lessonSession.v1"

    /// Injectable defaults keep the store testable in isolation (a throwaway
    /// suite) without touching the app's standard defaults.
    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    /// The saved in-progress session, or nil if there is none or it is unreadable.
    func load() -> LessonSessionSnapshot? {
        guard let data = defaults.data(forKey: key), !data.isEmpty else { return nil }
        guard let snapshot = try? JSONDecoder().decode(LessonSessionSnapshot.self, from: data),
              !snapshot.exercises.isEmpty else {
            return nil
        }
        return snapshot
    }

    func save(_ snapshot: LessonSessionSnapshot) {
        guard let data = try? JSONEncoder().encode(snapshot) else { return }
        defaults.set(data, forKey: key)
    }

    /// Clears the saved session. Called on completion, failure, a confirmed
    /// discard, and a learning-data reset. Forces a synchronize so the clear
    /// survives an immediate termination, matching the other destructive paths.
    func clear() {
        defaults.removeObject(forKey: key)
        defaults.synchronize()
    }
}
