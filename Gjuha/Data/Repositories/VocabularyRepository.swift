import Foundation
import Dependencies

// MARK: - Protocol

protocol VocabularyRepository: Sendable {
    func fetchAll() async -> [Word]
    func fetchByLevel(_ level: CEFRLevel) async -> [Word]
    func fetchByIds(_ ids: [UUID]) async -> [Word]
    func markLearned(_ wordId: UUID) async
    func search(_ query: String) async -> [Word]
}

// MARK: - Dependency Key

private enum VocabularyRepositoryKey: DependencyKey {
    static let liveValue: any VocabularyRepository = LiveVocabularyRepository()
    static let testValue: any VocabularyRepository = MockVocabularyRepository()
}

extension DependencyValues {
    var vocabularyRepository: any VocabularyRepository {
        get { self[VocabularyRepositoryKey.self] }
        set { self[VocabularyRepositoryKey.self] = newValue }
    }
}

// MARK: - Live Implementation

final class LiveVocabularyRepository: VocabularyRepository, @unchecked Sendable {
    private let words: [Word]

    init(bundle: Bundle = .main) {
        self.words = Self.loadSeedWords(bundle: bundle)
    }

    func fetchAll() async -> [Word] {
        words
    }

    func fetchByLevel(_ level: CEFRLevel) async -> [Word] {
        words.filter { $0.cefrLevel == level }
    }

    func fetchByIds(_ ids: [UUID]) async -> [Word] {
        let idSet = Set(ids)
        return words.filter { idSet.contains($0.id) }
    }

    func markLearned(_ wordId: UUID) async {
        // TODO: Persist learned state in SwiftData once store-backed repositories are enabled.
    }

    func search(_ query: String) async -> [Word] {
        guard !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return words
        }
        return words.filter {
            $0.albanian.localizedCaseInsensitiveContains(query) ||
            $0.english.localizedCaseInsensitiveContains(query)
        }
    }

    private static func loadSeedWords(bundle: Bundle) -> [Word] {
        var result: [Word] = []
        var seenKeys = Set<String>()

        if let seededJson: [SeedWordJSON] = decodeJSON(named: "a1_vocabulary", bundle: bundle) {
            for item in seededJson {
                let key = "json-\(item.id)"
                guard seenKeys.insert(key).inserted else { continue }
                result.append(
                    Word(
                        id: stableUUID(for: "word-\(item.id)"),
                        albanian: item.albanian,
                        english: item.english,
                        cefrLevel: parseCEFR(item.cefrLevel),
                        partOfSpeech: parsePartOfSpeech(item.partOfSpeech),
                        gender: parseGender(item.gender),
                        verbClass: parseVerbClass(item.verbClass),
                        exampleSentence: item.exampleSentence,
                        exampleTranslation: item.exampleTranslation,
                        frequency: item.frequency ?? 0
                    )
                )
            }
        }

        if let csvUrl = bundle.url(forResource: "vocabulary_seed_600", withExtension: "csv"),
           let rawCsv = try? String(contentsOf: csvUrl, encoding: .utf8) {
            let lines = rawCsv.components(separatedBy: .newlines).filter { !$0.isEmpty }
            for (index, line) in lines.enumerated() where index > 0 {
                let cols = parseCSVLine(line)
                guard cols.count >= 10 else { continue }
                let seedId = cols[0]
                let albanian = cols[1].isEmpty ? cols[2] : cols[1]
                let english = cols[8]
                guard !seedId.isEmpty, !albanian.isEmpty, !english.isEmpty else { continue }

                let key = "csv-\(seedId)"
                guard seenKeys.insert(key).inserted else { continue }

                result.append(
                    Word(
                        id: stableUUID(for: "word-\(seedId)"),
                        albanian: albanian,
                        english: english,
                        cefrLevel: parseCEFR(cols[9]),
                        partOfSpeech: parsePartOfSpeech(cols[3]),
                        gender: parseGender(cols[4]),
                        exampleSentence: nil,
                        exampleTranslation: nil,
                        audioFileName: cols[safe: 12],
                        frequency: max(1, 600 - index)
                    )
                )
            }
        }

        return result.isEmpty ? Word.mockData : result
    }

    private static func parseCSVLine(_ line: String) -> [String] {
        let chars = Array(line)
        var fields: [String] = []
        var current = ""
        var inQuotes = false
        var index = 0

        while index < chars.count {
            let char = chars[index]
            if char == "\"" {
                if inQuotes, index + 1 < chars.count, chars[index + 1] == "\"" {
                    current.append("\"")
                    index += 1
                } else {
                    inQuotes.toggle()
                }
            } else if char == "," && !inQuotes {
                fields.append(current.trimmingCharacters(in: .whitespaces))
                current = ""
            } else {
                current.append(char)
            }
            index += 1
        }

        fields.append(current.trimmingCharacters(in: .whitespaces))
        return fields
    }

    private static func parseCEFR(_ raw: String?) -> CEFRLevel {
        guard let raw else { return .a1 }
        return CEFRLevel(rawValue: raw.lowercased()) ?? .a1
    }

    private static func parsePartOfSpeech(_ raw: String?) -> PartOfSpeech {
        guard let raw = raw?.lowercased(), !raw.isEmpty else { return .noun }
        switch raw {
        case "noun": return .noun
        case "verb": return .verb
        case "adjective": return .adjective
        case "adverb": return .adverb
        case "pronoun": return .pronoun
        case "preposition": return .preposition
        case "conjunction": return .conjunction
        case "interjection": return .interjection
        case "numeral": return .numeral
        case "particle": return .particle
        case "phrase": return .interjection
        default: return .noun
        }
    }

    private static func parseGender(_ raw: String?) -> NounGender? {
        guard let raw = raw?.lowercased(), !raw.isEmpty else { return nil }
        switch raw {
        case "m", "masculine": return .masculine
        case "f", "feminine": return .feminine
        case "n", "neuter": return .neuter
        default: return nil
        }
    }

    private static func parseVerbClass(_ raw: String?) -> VerbClass? {
        guard let raw = raw?.lowercased(), !raw.isEmpty else { return nil }
        switch raw {
        case "firstconjugation", "first_conjugation", "first": return .firstConjugation
        case "secondconjugation", "second_conjugation", "second": return .secondConjugation
        case "thirdconjugation", "third_conjugation", "third": return .thirdConjugation
        case "irregular": return .irregular
        default: return nil
        }
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

    private struct SeedWordJSON: Decodable {
        let id: String
        let albanian: String
        let english: String
        let cefrLevel: String
        let partOfSpeech: String
        let gender: String?
        let verbClass: String?
        let exampleSentence: String?
        let exampleTranslation: String?
        let frequency: Int?
    }
}

private extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}

// MARK: - Mock Implementation (for tests and previews)

final class MockVocabularyRepository: VocabularyRepository, @unchecked Sendable {
    func fetchAll() async -> [Word] {
        return Word.mockData
    }

    func fetchByLevel(_ level: CEFRLevel) async -> [Word] {
        return Word.mockData.filter { $0.cefrLevel == level }
    }

    func fetchByIds(_ ids: [UUID]) async -> [Word] {
        return Word.mockData.filter { ids.contains($0.id) }
    }

    func markLearned(_ wordId: UUID) async {}

    func search(_ query: String) async -> [Word] {
        return Word.mockData.filter {
            $0.albanian.localizedCaseInsensitiveContains(query) ||
            $0.english.localizedCaseInsensitiveContains(query)
        }
    }
}

// MARK: - Mock Data

extension Word {
    nonisolated(unsafe) static let mockData: [Word] = [
        Word(albanian: "mirëdita", english: "good day / hello", cefrLevel: .a1, partOfSpeech: .interjection),
        Word(albanian: "faleminderit", english: "thank you", cefrLevel: .a1, partOfSpeech: .interjection),
        Word(albanian: "po", english: "yes", cefrLevel: .a1, partOfSpeech: .particle),
        Word(albanian: "jo", english: "no", cefrLevel: .a1, partOfSpeech: .particle),
        Word(albanian: "ujë", english: "water", cefrLevel: .a1, partOfSpeech: .noun, gender: .masculine),
        Word(albanian: "bukë", english: "bread", cefrLevel: .a1, partOfSpeech: .noun, gender: .feminine),
        Word(albanian: "shtëpi", english: "house", cefrLevel: .a1, partOfSpeech: .noun, gender: .feminine),
        Word(albanian: "punë", english: "work / job", cefrLevel: .a1, partOfSpeech: .noun, gender: .feminine),
        Word(albanian: "punoj", english: "I work", cefrLevel: .a1, partOfSpeech: .verb, verbClass: .firstConjugation),
        Word(albanian: "flas", english: "I speak", cefrLevel: .a1, partOfSpeech: .verb, verbClass: .thirdConjugation),
        Word(albanian: "dua", english: "I want / I love", cefrLevel: .a1, partOfSpeech: .verb, verbClass: .irregular),
        Word(albanian: "kam", english: "I have", cefrLevel: .a1, partOfSpeech: .verb, verbClass: .irregular),
        Word(albanian: "jam", english: "I am", cefrLevel: .a1, partOfSpeech: .verb, verbClass: .irregular),
    ]
}
