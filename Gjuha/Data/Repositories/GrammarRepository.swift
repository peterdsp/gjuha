import Foundation
import Dependencies

// MARK: - Protocol

protocol GrammarRepository: Sendable {
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

final class LiveGrammarRepository: GrammarRepository, @unchecked Sendable {
    private let topics: [GrammarTopic]
    private let topicsById: [UUID: GrammarTopic]

    init(bundle: Bundle = .main) {
        let loaded = Self.loadSeedTopics(bundle: bundle)
        self.topics = loaded
        self.topicsById = Dictionary(uniqueKeysWithValues: loaded.map { ($0.id, $0) })
    }

    func fetchTopics() async -> [GrammarTopic] {
        topics
    }

    func fetchTopic(_ id: UUID) async -> GrammarTopic? {
        topicsById[id]
    }

    func fetchTopicsByCategory(_ category: GrammarCategory) async -> [GrammarTopic] {
        topics.filter { $0.category == category }
    }

    private static func loadSeedTopics(bundle: Bundle) -> [GrammarTopic] {
        guard let seedTopics: [SeedGrammarTopic] = decodeJSON(named: "a1_grammar", bundle: bundle) else {
            return GrammarTopic.mockData
        }

        let mapped = seedTopics.map { item in
            GrammarTopic(
                id: stableUUID(for: "grammar-\(item.id)"),
                title: item.title,
                subtitle: item.subtitle,
                cefrLevel: CEFRLevel(rawValue: item.cefrLevel.lowercased()) ?? .a1,
                category: GrammarCategory(rawValue: item.category) ?? .verbs,
                explanation: item.explanation,
                conjugationTable: item.conjugationTable,
                examples: item.examples
            )
        }

        return mapped.isEmpty ? GrammarTopic.mockData : mapped
    }

    private static func decodeJSON<T: Decodable>(named name: String, bundle: Bundle) -> T? {
        guard let url = bundle.url(forResource: name, withExtension: "json") else {
            return nil
        }
        guard let data = try? Data(contentsOf: url) else {
            return nil
        }
        return try? JSONDecoder().decode(T.self, from: data)
    }

    private static func stableUUID(for raw: String) -> UUID {
        var bytes = [UInt8](repeating: 0, count: 16)
        for (index, value) in raw.utf8.enumerated() {
            bytes[index % 16] = bytes[index % 16] &+ value
        }
        bytes[6] = (bytes[6] & 0x0F) | 0x40
        bytes[8] = (bytes[8] & 0x3F) | 0x80
        return UUID(uuid: (
            bytes[0], bytes[1], bytes[2], bytes[3],
            bytes[4], bytes[5], bytes[6], bytes[7],
            bytes[8], bytes[9], bytes[10], bytes[11],
            bytes[12], bytes[13], bytes[14], bytes[15]
        ))
    }

    private struct SeedGrammarTopic: Decodable {
        let id: String
        let title: String
        let subtitle: String
        let cefrLevel: String
        let category: String
        let explanation: String
        let conjugationTable: [[String]]
        let examples: [String]
    }
}

// MARK: - Mock Implementation

final class MockGrammarRepository: GrammarRepository, @unchecked Sendable {
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
