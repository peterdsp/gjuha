import Foundation
import Dependencies

// MARK: - Protocol

protocol GrammarRepository {
    func fetchTopics() async -> [GrammarTopic]
    func fetchTopic(_ id: UUID) async -> GrammarTopic?
    func fetchTopicsByCategory(_ category: GrammarCategory) async -> [GrammarTopic]
}

// MARK: - Dependency Key

private enum GrammarRepositoryKey: DependencyKey {
    static let liveValue: any GrammarRepository = LiveGrammarRepository()
    static let testValue: any GrammarRepository = MockGrammarRepository()
}

extension DependencyValues {
    var grammarRepository: any GrammarRepository {
        get { self[GrammarRepositoryKey.self] }
        set { self[GrammarRepositoryKey.self] = newValue }
    }
}

// MARK: - Live Implementation

final class LiveGrammarRepository: GrammarRepository {
    func fetchTopics() async -> [GrammarTopic] { [] }
    func fetchTopic(_ id: UUID) async -> GrammarTopic? { nil }
    func fetchTopicsByCategory(_ category: GrammarCategory) async -> [GrammarTopic] { [] }
}

// MARK: - Mock Implementation

final class MockGrammarRepository: GrammarRepository {
    func fetchTopics() async -> [GrammarTopic] { GrammarTopic.mockData }

    func fetchTopic(_ id: UUID) async -> GrammarTopic? {
        GrammarTopic.mockData.first { $0.id == id }
    }

    func fetchTopicsByCategory(_ category: GrammarCategory) async -> [GrammarTopic] {
        GrammarTopic.mockData.filter { $0.category == category }
    }
}

// MARK: - Mock Data

extension GrammarTopic {
    static let mockData: [GrammarTopic] = [
        GrammarTopic(
            title: "The verb 'to be': jam",
            subtitle: "Present tense conjugation",
            cefrLevel: .a1,
            category: .verbs,
            explanation: """
            In Albanian, the verb 'to be' (jam) is irregular, just like in most European languages. \
            It must agree with the subject in person and number.

            Albanian has two numbers (singular, plural) and three persons, giving six distinct forms.
            """,
            conjugationTable: [
                ["Person", "Singular", "Plural"],
                ["1st", "jam (I am)", "jemi (we are)"],
                ["2nd", "je (you are)", "jeni (you are)"],
                ["3rd", "është (he/she/it is)", "janë (they are)"],
            ],
            examples: [
                "Unë jam student. — I am a student.",
                "Ti je shqiptar. — You are Albanian.",
                "Ai është mësues. — He is a teacher.",
                "Ne jemi miq. — We are friends.",
            ]
        ),
        GrammarTopic(
            title: "Noun Gender",
            subtitle: "Masculine and feminine nouns",
            cefrLevel: .a1,
            category: .nouns,
            explanation: """
            Albanian nouns are either masculine or feminine (with a rare neuter class in some dialects). \
            Gender affects article forms, adjective agreement, and case endings.

            Masculine nouns often end in a consonant in indefinite form: libër (book), mik (friend).
            Feminine nouns often end in -ë or -e: vajzë (girl), shtëpi (house).

            There are exceptions — learning gender by association with vocabulary is recommended.
            """,
            examples: [
                "libri (the book) — masculine",
                "vajza (the girl) — feminine",
                "miku (the friend) — masculine",
                "shtëpia (the house) — feminine",
            ]
        ),
    ]
}
