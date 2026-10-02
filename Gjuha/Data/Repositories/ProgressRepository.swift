import Foundation
import Dependencies

// MARK: - Protocol

protocol ProgressRepository: Sendable {
    func fetchUserStats() async -> UserStats
    func markLessonCompleted(_ lessonId: UUID, seedId: String, xpEarned: Int) async
    func updateStreak() async
    func fetchCurrentStreak() async -> Int
    func fetchTotalXP() async -> Int
    func fetchLearningGoal() async -> LearningGoal
    func saveLearningGoal(_ goal: LearningGoal) async
}

// MARK: - Dependency Key

private enum ProgressRepositoryKey: DependencyKey {
    static let liveValue: any ProgressRepository = LiveProgressRepository()
    static let testValue: any ProgressRepository = MockProgressRepository()
}

extension DependencyValues {
    var progressRepository: any ProgressRepository {
        get { self[ProgressRepositoryKey.self] }
        set { self[ProgressRepositoryKey.self] = newValue }
    }
}

// MARK: - Live Implementation

final class LiveProgressRepository: ProgressRepository, @unchecked Sendable {
    private let reviewRepository: any ReviewRepository

    init(reviewRepository: any ReviewRepository = LiveReviewRepository()) {
        self.reviewRepository = reviewRepository
    }

    func fetchUserStats() async -> UserStats {
        let store = ProgressStore.shared
        let retention = await reviewRepository.summary()
        return UserStats(
            currentStreak: store.currentStreak,
            totalXP: store.totalXP,
            wordsSeen: Self.wordsSeen(in: store.completedLessonSeedIds),
            lessonsCompleted: store.lessonsCompleted,
            wordsPracticed: retention.wordsPracticed,
            wordsMastered: retention.wordsMastered
        )
    }

    /// Honest exposure count: the distinct vocabulary words covered by the
    /// lessons the user has actually completed, taken from the fixed
    /// lesson-to-vocabulary mapping. Not a fabricated multiple of lesson count,
    /// and not presented as mastery.
    static func wordsSeen(in completedSeedIds: Set<String>) -> Int {
        var ids = Set<String>()
        for seedId in completedSeedIds {
            ids.formUnion(LessonVocabularyMap.wordIds(for: seedId, lessonTitle: ""))
        }
        return ids.count
    }

    func markLessonCompleted(_ lessonId: UUID, seedId: String, xpEarned: Int) async {
        ProgressStore.shared.markLessonCompleted(seedId: seedId, xpEarned: xpEarned)
    }

    func updateStreak() async {
        ProgressStore.shared.markDailyActivity()
    }

    func fetchCurrentStreak() async -> Int {
        ProgressStore.shared.currentStreak
    }

    func fetchTotalXP() async -> Int {
        ProgressStore.shared.totalXP
    }

    func fetchLearningGoal() async -> LearningGoal {
        guard let raw = ProgressStore.shared.learningGoalRawValue,
              let goal = LearningGoal(rawValue: raw) else {
            return .casual
        }
        return goal
    }

    func saveLearningGoal(_ goal: LearningGoal) async {
        ProgressStore.shared.setLearningGoal(goal.rawValue)
    }
}

// MARK: - Mock Implementation

final class MockProgressRepository: ProgressRepository, @unchecked Sendable {
    func fetchUserStats() async -> UserStats {
        return UserStats(
            currentStreak: 7,
            totalXP: 340,
            wordsSeen: 45,
            lessonsCompleted: 12,
            wordsPracticed: 38,
            wordsMastered: 16
        )
    }

    func markLessonCompleted(_ lessonId: UUID, seedId: String, xpEarned: Int) async {}
    func updateStreak() async {}
    func fetchCurrentStreak() async -> Int { 7 }
    func fetchTotalXP() async -> Int { 340 }
    func fetchLearningGoal() async -> LearningGoal { .regular }
    func saveLearningGoal(_ goal: LearningGoal) async {}
}
