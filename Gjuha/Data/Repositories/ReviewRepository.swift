import Foundation
import Dependencies

// MARK: - Retention summary

/// Honest breakdown of what the schedule knows, kept distinct from exposure.
///
/// `wordsPracticed` is every word that has entered the review schedule (introduced
/// by completing a lesson). `wordsMastered` is the subset that has climbed to the
/// documented mastery interval. `dueCount` is how many are due right now. None of
/// these is inflated from lesson count.
struct RetentionSummary: Equatable, Sendable {
    var wordsPracticed: Int
    var wordsMastered: Int
    var dueCount: Int
}

// MARK: - Protocol

protocol ReviewRepository: Sendable {
    /// Adds schedule entries for words just learned in a lesson. Words already
    /// scheduled keep their existing progress.
    func scheduleNewWords(_ wordIds: [String]) async
    /// How many words are due for review now.
    func dueCount() async -> Int
    /// Stable, struggling first ordering of word ids due now, capped at `limit`.
    func dueWordIds(limit: Int) async -> [String]
    /// Records a single review outcome and reschedules the word.
    func recordOutcome(wordId: String, grade: ReviewGrade) async
    /// Aggregate retention stats for the Profile screen.
    func summary() async -> RetentionSummary
}

// MARK: - Dependency Key

private enum ReviewRepositoryKey: DependencyKey {
    static let liveValue: any ReviewRepository = LiveReviewRepository()
    static let testValue: any ReviewRepository = MockReviewRepository()
}

extension DependencyValues {
    var reviewRepository: any ReviewRepository {
        get { self[ReviewRepositoryKey.self] }
        set { self[ReviewRepositoryKey.self] = newValue }
    }
}

// MARK: - Live Implementation

final class LiveReviewRepository: ReviewRepository, @unchecked Sendable {
    private let store: ReviewStore
    private let scheduler: ReviewScheduler

    init(store: ReviewStore = .shared, scheduler: ReviewScheduler = ReviewScheduler()) {
        self.store = store
        self.scheduler = scheduler
    }

    func scheduleNewWords(_ wordIds: [String]) async {
        let now = Date()
        let newItems = wordIds.map { scheduler.newItem(wordId: $0, now: now) }
        store.insertNewItems(newItems)
    }

    func dueCount() async -> Int {
        let items = Array(store.load().values)
        return scheduler.dueItems(from: items, now: Date()).count
    }

    func dueWordIds(limit: Int) async -> [String] {
        let items = Array(store.load().values)
        return scheduler.dueItems(from: items, now: Date(), limit: limit).map(\.wordId)
    }

    func recordOutcome(wordId: String, grade: ReviewGrade) async {
        let items = store.load()
        let now = Date()
        // Reviewing a word that was never scheduled (defensive): introduce it first.
        let current = items[wordId] ?? scheduler.newItem(wordId: wordId, now: now)
        let updated = scheduler.apply(grade, to: current, now: now)
        store.upsert(updated)
    }

    func summary() async -> RetentionSummary {
        let items = Array(store.load().values)
        let now = Date()
        return RetentionSummary(
            wordsPracticed: items.count,
            wordsMastered: items.filter { scheduler.isMastered($0) }.count,
            dueCount: scheduler.dueItems(from: items, now: now).count
        )
    }
}

// MARK: - Mock Implementation

final class MockReviewRepository: ReviewRepository, @unchecked Sendable {
    func scheduleNewWords(_ wordIds: [String]) async {}
    func dueCount() async -> Int { 0 }
    func dueWordIds(limit: Int) async -> [String] { [] }
    func recordOutcome(wordId: String, grade: ReviewGrade) async {}
    func summary() async -> RetentionSummary {
        RetentionSummary(wordsPracticed: 0, wordsMastered: 0, dueCount: 0)
    }
}
