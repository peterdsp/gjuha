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
    func fetchAll() async -> [Word] {
        // TODO: Fetch from SwiftData container
        return []
    }

    func fetchByLevel(_ level: CEFRLevel) async -> [Word] {
        return []
    }

    func fetchByIds(_ ids: [UUID]) async -> [Word] {
        return []
    }

    func markLearned(_ wordId: UUID) async {
        // TODO: Update SwiftData model
    }

    func search(_ query: String) async -> [Word] {
        return []
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
