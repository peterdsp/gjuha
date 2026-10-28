import Foundation
import SwiftData

struct GrammarTopic: Identifiable, Equatable {
    let id: UUID
    let title: String
    let subtitle: String
    let cefrLevel: CEFRLevel
    let category: GrammarCategory
    let explanation: String
    let conjugationTable: [[String]]
    let examples: [String]
    let relatedTopicIds: [UUID]

    init(
        id: UUID = UUID(),
        title: String,
        subtitle: String,
        cefrLevel: CEFRLevel,
        category: GrammarCategory,
        explanation: String,
        conjugationTable: [[String]] = [],
        examples: [String] = [],
        relatedTopicIds: [UUID] = []
    ) {
        self.id = id
        self.title = title
        self.subtitle = subtitle
        self.cefrLevel = cefrLevel
        self.category = category
        self.explanation = explanation
        self.conjugationTable = conjugationTable
        self.examples = examples
        self.relatedTopicIds = relatedTopicIds
    }
}

enum GrammarCategory: String, Codable, CaseIterable {
    case nouns             // Declension, gender, definiteness
    case verbs             // Conjugation, tenses, moods
    case adjectives        // Agreement, comparison
    case pronouns          // Personal, possessive, demonstrative
    case numbers           // Cardinal, ordinal
    case cases             // Nominative, accusative, genitive, dative, ablative
    case wordOrder         // Albanian SOV tendencies
    case negation
    case questions
}

struct UserStats: Equatable {
    let currentStreak: Int
    let totalXP: Int
    /// Distinct vocabulary words the user has been exposed to through completed
    /// lessons. This is honest exposure ("seen"), not a mastery claim.
    let wordsSeen: Int
    let lessonsCompleted: Int
    /// Words that have entered the spaced repetition schedule (reviewed at least
    /// once beyond the lesson that introduced them is not required; being scheduled
    /// means the learner has committed to retaining them). Distinct from "seen".
    let wordsPracticed: Int
    /// The subset of practiced words that have climbed to the documented mastery
    /// interval in the scheduler. This is the only figure presented as mastery.
    let wordsMastered: Int
    /// XP earned since local midnight. Resets by calendar day, not by timer.
    let xpToday: Int
    /// XP that meets the learner's chosen daily goal. See
    /// `LearningGoal.dailyXPGoal`.
    let dailyGoalXP: Int

    init(
        currentStreak: Int,
        totalXP: Int,
        wordsSeen: Int,
        lessonsCompleted: Int,
        wordsPracticed: Int = 0,
        wordsMastered: Int = 0,
        xpToday: Int = 0,
        dailyGoalXP: Int = LearningGoal.casual.dailyXPGoal
    ) {
        self.currentStreak = currentStreak
        self.totalXP = totalXP
        self.wordsSeen = wordsSeen
        self.lessonsCompleted = lessonsCompleted
        self.wordsPracticed = wordsPracticed
        self.wordsMastered = wordsMastered
        self.xpToday = xpToday
        self.dailyGoalXP = dailyGoalXP
    }

    /// Today's progress toward the daily goal, clamped to 0...1.
    ///
    /// Clamped because the ring that draws it cannot overfill, while the XP
    /// number next to it is not clamped: a learner who doubles their goal should
    /// see that they did.
    var dailyGoalProgress: Double {
        guard dailyGoalXP > 0 else { return 0 }
        return min(1.0, Double(xpToday) / Double(dailyGoalXP))
    }

    var hasMetDailyGoal: Bool { dailyGoalXP > 0 && xpToday >= dailyGoalXP }

    static let empty = UserStats(
        currentStreak: 0,
        totalXP: 0,
        wordsSeen: 0,
        lessonsCompleted: 0
    )
}
