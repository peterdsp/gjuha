import Foundation

/// Lightweight UserDefaults-backed persistence for lesson completion and XP.
/// Phase 1 solution — will migrate to SwiftData in Phase 2.
final class ProgressStore: @unchecked Sendable {
    static let shared = ProgressStore()

    private let defaults: UserDefaults

    /// Injectable defaults keep the store testable in isolation (a throwaway
    /// suite) without touching the app's standard defaults.
    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    private enum Keys {
        static let completedLessons = "gjuha.completedLessonSeedIds"
        static let xpByLesson = "gjuha.xpByLesson"
        static let totalXP = "gjuha.totalXP"
        static let currentStreak = "gjuha.currentStreak"
        static let lastActivityDate = "gjuha.lastActivityDate"
        static let learningGoal = "gjuha.learningGoal"
    }

    // MARK: - Completed Lessons

    var completedLessonSeedIds: Set<String> {
        let array = defaults.stringArray(forKey: Keys.completedLessons) ?? []
        return Set(array)
    }

    func markLessonCompleted(seedId: String, xpEarned: Int) {
        var completed = defaults.stringArray(forKey: Keys.completedLessons) ?? []
        if !completed.contains(seedId) {
            completed.append(seedId)
            defaults.set(completed, forKey: Keys.completedLessons)
        }

        // Track best XP per lesson
        var xpMap = defaults.dictionary(forKey: Keys.xpByLesson) as? [String: Int] ?? [:]
        let current = xpMap[seedId] ?? 0
        if xpEarned > current {
            xpMap[seedId] = xpEarned
            defaults.set(xpMap, forKey: Keys.xpByLesson)
        }

        // Update total XP
        let total = defaults.integer(forKey: Keys.totalXP) + xpEarned
        defaults.set(total, forKey: Keys.totalXP)

        // Update streak
        updateStreak()
    }

    func bestXP(for seedId: String) -> Int {
        let xpMap = defaults.dictionary(forKey: Keys.xpByLesson) as? [String: Int] ?? [:]
        return xpMap[seedId] ?? 0
    }

    var totalXP: Int {
        defaults.integer(forKey: Keys.totalXP)
    }

    // MARK: - Streak

    var currentStreak: Int {
        defaults.integer(forKey: Keys.currentStreak)
    }

    private func updateStreak() {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())

        if let lastDate = defaults.object(forKey: Keys.lastActivityDate) as? Date {
            let lastDay = calendar.startOfDay(for: lastDate)
            let daysDiff = calendar.dateComponents([.day], from: lastDay, to: today).day ?? 0

            if daysDiff == 0 {
                // Already practiced today
                return
            } else if daysDiff == 1 {
                // Consecutive day
                let streak = defaults.integer(forKey: Keys.currentStreak) + 1
                defaults.set(streak, forKey: Keys.currentStreak)
            } else {
                // Streak broken
                defaults.set(1, forKey: Keys.currentStreak)
            }
        } else {
            // First ever activity
            defaults.set(1, forKey: Keys.currentStreak)
        }

        defaults.set(today, forKey: Keys.lastActivityDate)
    }

    // MARK: - Stats

    var lessonsCompleted: Int {
        completedLessonSeedIds.count
    }

    // MARK: - Learning Goal

    /// Raw stored goal identifier, or nil if the user has not set one yet.
    var learningGoalRawValue: String? {
        defaults.string(forKey: Keys.learningGoal)
    }

    func setLearningGoal(_ rawValue: String) {
        defaults.set(rawValue, forKey: Keys.learningGoal)
    }
}
