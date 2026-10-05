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
    /// When the snapshot was written, for diagnostics.
    var savedAt: Date
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
