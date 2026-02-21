import Foundation
import Dependencies

// MARK: - Protocol

protocol ProgressRepository {
    func fetchUserStats() async -> UserStats
    func markLessonCompleted(_ lessonId: UUID, xpEarned: Int) async
    func updateStreak() async
    func fetchCurrentStreak() async -> Int
    func fetchTotalXP() async -> Int
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

final class LiveProgressRepository: ProgressRepository {
    func fetchUserStats() async -> UserStats {
        // TODO: Aggregate from SwiftData
        return .empty
    }

    func markLessonCompleted(_ lessonId: UUID, xpEarned: Int) async {
        // TODO: Persist to SwiftData, update XP, check streak
    }

    func updateStreak() async {
        // TODO: Check last activity date, increment or reset streak
    }

    func fetchCurrentStreak() async -> Int { 0 }
    func fetchTotalXP() async -> Int { 0 }
}

// MARK: - Mock Implementation

final class MockProgressRepository: ProgressRepository {
    func fetchUserStats() async -> UserStats {
        return UserStats(
            currentStreak: 7,
            totalXP: 340,
            wordsLearned: 45,
            lessonsCompleted: 12
        )
    }

    func markLessonCompleted(_ lessonId: UUID, xpEarned: Int) async {}
    func updateStreak() async {}
    func fetchCurrentStreak() async -> Int { 7 }
    func fetchTotalXP() async -> Int { 340 }
}
