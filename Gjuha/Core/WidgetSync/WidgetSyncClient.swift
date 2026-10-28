import Foundation
import Dependencies
#if canImport(WidgetKit)
import WidgetKit
#endif

/// Rebuilds the widget's projection of learner state and asks WidgetKit to redraw.
///
/// This is the only writer of `GjuhaWidgetSnapshot`. It reads the canonical stores
/// and derives the snapshot, so the widget can never drift from the app: if the
/// projection is missing or stale the widget shows its placeholder, and the next
/// refresh rebuilds it from scratch.
///
/// Call it at the few points where learner state actually changes (finishing a
/// lesson or review, resetting data, finishing onboarding, launching). It is cheap
/// and idempotent, so an extra call is harmless.
protocol WidgetSyncClient: Sendable {
    func refresh() async
}

private enum WidgetSyncClientKey: DependencyKey {
    static let liveValue: any WidgetSyncClient = LiveWidgetSyncClient()
    /// Tests must not touch the App Group or WidgetKit.
    static let testValue: any WidgetSyncClient = NoopWidgetSyncClient()
    static let previewValue: any WidgetSyncClient = NoopWidgetSyncClient()
}

extension DependencyValues {
    var widgetSync: any WidgetSyncClient {
        get { self[WidgetSyncClientKey.self] }
        set { self[WidgetSyncClientKey.self] = newValue }
    }
}

// MARK: - Live

final class LiveWidgetSyncClient: WidgetSyncClient, @unchecked Sendable {
    private let progressStore: ProgressStore
    private let reviewRepository: any ReviewRepository
    private let snapshotStore: WidgetSnapshotStore

    init(
        progressStore: ProgressStore = .shared,
        reviewRepository: any ReviewRepository = LiveReviewRepository(),
        snapshotStore: WidgetSnapshotStore = .shared
    ) {
        self.progressStore = progressStore
        self.reviewRepository = reviewRepository
        self.snapshotStore = snapshotStore
    }

    func refresh() async {
        let retention = await reviewRepository.summary()

        // A fresh repository, not a cached one: completion state lives in
        // UserDefaults and the cached instance would report pre-lesson data.
        let units = await LiveCurriculumRepository().fetchUnits()

        let goal = LearningGoal(rawValue: progressStore.learningGoalRawValue ?? "") ?? .casual

        let snapshot = GjuhaWidgetSnapshot(
            currentStreak: progressStore.currentStreak,
            totalXP: progressStore.totalXP,
            dueReviewCount: retention.dueCount,
            wordsMastered: retention.wordsMastered,
            nextLessonTitle: Self.nextLessonTitle(in: units),
            practicedToday: progressStore.hasPracticedToday,
            xpToday: progressStore.xpEarnedToday,
            dailyGoalXP: goal.dailyXPGoal,
            generatedAt: Date()
        )

        snapshotStore.write(snapshot)
        reloadTimelines()
    }

    /// The first lesson the learner can actually open next: in unit then lesson
    /// order, the first one that is neither locked nor already completed. Nil when
    /// everything reachable is done.
    static func nextLessonTitle(in units: [LearningUnit]) -> String? {
        units
            .sorted { $0.orderIndex < $1.orderIndex }
            .flatMap { $0.lessons.sorted { $0.orderIndex < $1.orderIndex } }
            .first { !$0.isLocked && !$0.isCompleted }?
            .title
    }

    private func reloadTimelines() {
        #if canImport(WidgetKit)
        WidgetCenter.shared.reloadAllTimelines()
        #endif
    }
}

// MARK: - No-op

/// Used in tests and previews so neither touches the App Group or WidgetKit.
struct NoopWidgetSyncClient: WidgetSyncClient {
    func refresh() async {}
}
