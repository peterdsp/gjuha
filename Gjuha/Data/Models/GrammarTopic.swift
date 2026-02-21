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
    let wordsLearned: Int
    let lessonsCompleted: Int

    static let empty = UserStats(
        currentStreak: 0,
        totalXP: 0,
        wordsLearned: 0,
        lessonsCompleted: 0
    )
}
