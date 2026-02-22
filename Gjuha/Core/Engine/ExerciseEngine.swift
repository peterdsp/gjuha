import Foundation
import Dependencies

// MARK: - Protocol

protocol ExerciseEngineProtocol: Sendable {
    func generateExercises(for lesson: LessonSummary) async -> [Exercise]
    func checkAnswer(_ answer: String, for exercise: Exercise) -> Bool
}

// MARK: - Dependency Key

private enum ExerciseEngineKey: DependencyKey {
    static let liveValue: any ExerciseEngineProtocol = ExerciseEngine()
    static let testValue: any ExerciseEngineProtocol = MockExerciseEngine()
}

extension DependencyValues {
    var exerciseEngine: any ExerciseEngineProtocol {
        get { self[ExerciseEngineKey.self] }
        set { self[ExerciseEngineKey.self] = newValue }
    }
}

// MARK: - Lesson → Vocabulary Mapping

/// Maps lesson seed IDs to vocabulary word IDs for exercise generation
enum LessonVocabularyMap {
    /// Returns word IDs from the seed vocabulary that match a given lesson topic
    static func wordIds(for lessonSeedId: String, lessonTitle: String) -> [String] {
        if let explicit = explicitMapping[lessonSeedId] {
            return explicit
        }
        return inferWordIds(from: lessonTitle)
    }

    private static let explicitMapping: [String: [String]] = [
        "L001": ["w001", "w002", "w003", "w004", "w005", "w006", "w007", "w008", "w009"],
        "L002": ["w010", "w011", "w012", "w013", "w014", "w015", "w016", "w017", "w018"],
        "L003": ["w031", "w032", "w033", "w034", "w035", "w036", "w037", "w038", "w039", "w040"],
        "L004": ["w028", "w026", "w020", "w025", "w024", "w007", "w006"],
        "L005": ["w041", "w042", "w043", "w044", "w045", "w046", "w047"],
        "L006": ["w026", "w027", "w028", "w024", "w025", "w029", "w030"],
        "L007": ["w023", "w029"],
        "L008": ["w029", "w022", "w024", "w025", "w026", "w027"],
        "L009": [],
        "L010": ["w018", "w019", "w020", "w021", "w022", "w023"],
    ]

    private static func inferWordIds(from title: String) -> [String] {
        let lowered = title.lowercased()
        if lowered.contains("greeting") || lowered.contains("introduc") {
            return ["w001", "w002", "w003", "w004", "w005", "w006", "w007", "w008", "w009"]
        }
        if lowered.contains("pronoun") || lowered.contains("to be") {
            return ["w010", "w011", "w012", "w013", "w014", "w015", "w016", "w017", "w018"]
        }
        if lowered.contains("number") || lowered.contains("time") {
            return ["w031", "w032", "w033", "w034", "w035", "w036", "w037", "w038", "w039", "w040"]
        }
        if lowered.contains("food") || lowered.contains("coffee") || lowered.contains("ordering") || lowered.contains("market") {
            return ["w026", "w027", "w028", "w024", "w025", "w020", "w007"]
        }
        if lowered.contains("family") || lowered.contains("people") {
            return ["w041", "w042", "w043", "w044", "w045", "w046", "w047"]
        }
        if lowered.contains("work") || lowered.contains("study") {
            return ["w022", "w030", "w029"]
        }
        if lowered.contains("verb") || lowered.contains("past") || lowered.contains("tense") {
            return ["w018", "w019", "w020", "w021", "w022", "w023", "w024", "w025"]
        }
        // Fallback: use first batch of words
        return ["w001", "w002", "w003", "w005", "w006", "w008", "w009"]
    }
}

// MARK: - Live Engine

final class ExerciseEngine: ExerciseEngineProtocol, @unchecked Sendable {
    private let allWords: [SeedWordEntry]

    init(bundle: Bundle = .main) {
        self.allWords = Self.loadAllVocabulary(bundle: bundle)
    }

    func generateExercises(for lesson: LessonSummary) async -> [Exercise] {
        let targetWordIds = LessonVocabularyMap.wordIds(
            for: lesson.seedId,
            lessonTitle: lesson.title
        )

        let lessonWords = targetWordIds.compactMap { wId in
            allWords.first { $0.id == wId }
        }

        guard !lessonWords.isEmpty else {
            // Use first 8 words as fallback for any lesson
            let fallback = Array(allWords.prefix(8))
            return generateMixedExercises(from: fallback)
        }

        return generateMixedExercises(from: lessonWords)
    }

    func checkAnswer(_ answer: String, for exercise: Exercise) -> Bool {
        let normalizedAnswer = answer
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
            .replacingOccurrences(of: "\u{00eb}", with: "ë") // normalize ë
        let normalizedCorrect = exercise.correctAnswer
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()

        // Exact match
        if normalizedAnswer == normalizedCorrect { return true }

        // Handle "x / y" style answers — accept either part
        if normalizedCorrect.contains(" / ") {
            let parts = normalizedCorrect
                .components(separatedBy: " / ")
                .map { $0.trimmingCharacters(in: .whitespaces).lowercased() }
            if parts.contains(normalizedAnswer) { return true }
        }

        return false
    }

    // MARK: - Exercise Generation

    private func generateMixedExercises(from words: [SeedWordEntry]) -> [Exercise] {
        var exercises: [Exercise] = []
        let shuffled = words.shuffled()
        let pool = allWords // for distractors

        for (index, word) in shuffled.prefix(6).enumerated() {
            switch index % 3 {
            case 0:
                exercises.append(makeMCQAlbanianToEnglish(word: word, pool: pool))
            case 1:
                exercises.append(makeMCQEnglishToAlbanian(word: word, pool: pool))
            case 2:
                exercises.append(makeTranslateTextInput(word: word))
            default:
                break
            }
        }

        // Add a fill-in-the-blank if we have example sentences
        if let wordWithExample = shuffled.first(where: { $0.exampleSentence != nil }) {
            exercises.append(makeFillInBlank(word: wordWithExample, pool: pool))
        }

        return exercises.isEmpty ? Exercise.mockExercises : exercises
    }

    private func makeMCQAlbanianToEnglish(word: SeedWordEntry, pool: [SeedWordEntry]) -> Exercise {
        let distractors = pickDistractors(for: word, from: pool, count: 3, useEnglish: true)
        return Exercise(
            type: .multipleChoiceTranslate,
            prompt: "What does '\(word.albanian)' mean?",
            correctAnswer: word.english,
            distractors: distractors,
            explanation: word.exampleSentence.map { "Example: \($0)" },
            xpValue: 10
        )
    }

    private func makeMCQEnglishToAlbanian(word: SeedWordEntry, pool: [SeedWordEntry]) -> Exercise {
        let distractors = pickDistractors(for: word, from: pool, count: 3, useEnglish: false)
        return Exercise(
            type: .multipleChoiceTranslate,
            prompt: "How do you say '\(word.english)' in Albanian?",
            correctAnswer: word.albanian,
            distractors: distractors,
            xpValue: 10
        )
    }

    private func makeTranslateTextInput(word: SeedWordEntry) -> Exercise {
        // Randomly choose direction
        let toAlbanian = Bool.random()
        if toAlbanian {
            return Exercise(
                type: .translateTextInput,
                prompt: "Translate: '\(word.english)'",
                correctAnswer: word.albanian,
                hint: "Type in Albanian",
                xpValue: 15
            )
        } else {
            return Exercise(
                type: .translateTextInput,
                prompt: "Translate: '\(word.albanian)'",
                correctAnswer: word.english,
                hint: "Type in English",
                xpValue: 15
            )
        }
    }

    private func makeFillInBlank(word: SeedWordEntry, pool: [SeedWordEntry]) -> Exercise {
        guard let sentence = word.exampleSentence, let translation = word.exampleTranslation else {
            return makeMCQAlbanianToEnglish(word: word, pool: pool)
        }
        let blank = sentence.replacingOccurrences(of: word.albanian, with: "___")
        // Only create fill-in-blank if we actually replaced something
        guard blank != sentence else {
            return makeMCQAlbanianToEnglish(word: word, pool: pool)
        }
        let distractors = pickDistractors(for: word, from: pool, count: 3, useEnglish: false)
        return Exercise(
            type: .fillInBlank,
            prompt: "\(blank) (\(translation))",
            correctAnswer: word.albanian,
            distractors: distractors,
            xpValue: 12
        )
    }

    private func pickDistractors(
        for word: SeedWordEntry,
        from pool: [SeedWordEntry],
        count: Int,
        useEnglish: Bool
    ) -> [String] {
        let candidates = pool.filter { $0.id != word.id }
        let shuffled = candidates.shuffled()
        let picked = shuffled.prefix(count)
        return picked.map { useEnglish ? $0.english : $0.albanian }
    }

    // MARK: - Load Vocabulary

    private static func loadAllVocabulary(bundle: Bundle) -> [SeedWordEntry] {
        guard let url = bundle.url(forResource: "a1_vocabulary", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let words = try? JSONDecoder().decode([SeedWordEntry].self, from: data) else {
            return SeedWordEntry.fallback
        }
        return words.isEmpty ? SeedWordEntry.fallback : words
    }
}

// MARK: - Seed Word Entry (lightweight decode-only)

struct SeedWordEntry: Decodable, Sendable {
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

    static let fallback: [SeedWordEntry] = [
        SeedWordEntry(id: "w001", albanian: "mirëdita", english: "good day / hello", cefrLevel: "a1", partOfSpeech: "interjection", gender: nil, verbClass: nil, exampleSentence: "Mirëdita! Si jeni?", exampleTranslation: "Good day! How are you?", frequency: 1),
        SeedWordEntry(id: "w005", albanian: "mirupafshim", english: "goodbye", cefrLevel: "a1", partOfSpeech: "interjection", gender: nil, verbClass: nil, exampleSentence: nil, exampleTranslation: nil, frequency: 5),
        SeedWordEntry(id: "w006", albanian: "faleminderit", english: "thank you", cefrLevel: "a1", partOfSpeech: "interjection", gender: nil, verbClass: nil, exampleSentence: nil, exampleTranslation: nil, frequency: 6),
        SeedWordEntry(id: "w008", albanian: "po", english: "yes", cefrLevel: "a1", partOfSpeech: "particle", gender: nil, verbClass: nil, exampleSentence: nil, exampleTranslation: nil, frequency: 8),
        SeedWordEntry(id: "w009", albanian: "jo", english: "no", cefrLevel: "a1", partOfSpeech: "particle", gender: nil, verbClass: nil, exampleSentence: nil, exampleTranslation: nil, frequency: 9),
        SeedWordEntry(id: "w018", albanian: "jam", english: "I am / to be (1st sg)", cefrLevel: "a1", partOfSpeech: "verb", gender: nil, verbClass: "irregular", exampleSentence: "Unë jam shqiptar.", exampleTranslation: "I am Albanian.", frequency: 18),
        SeedWordEntry(id: "w019", albanian: "kam", english: "I have / to have (1st sg)", cefrLevel: "a1", partOfSpeech: "verb", gender: nil, verbClass: "irregular", exampleSentence: "Unë kam një libër.", exampleTranslation: "I have a book.", frequency: 19),
        SeedWordEntry(id: "w026", albanian: "ujë", english: "water", cefrLevel: "a1", partOfSpeech: "noun", gender: "m", verbClass: nil, exampleSentence: nil, exampleTranslation: nil, frequency: 26),
    ]
}

// MARK: - Mock Engine

final class MockExerciseEngine: ExerciseEngineProtocol, @unchecked Sendable {
    func generateExercises(for lesson: LessonSummary) async -> [Exercise] {
        return Exercise.mockExercises
    }

    func checkAnswer(_ answer: String, for exercise: Exercise) -> Bool {
        return answer.lowercased() == exercise.correctAnswer.lowercased()
    }
}

// MARK: - Mock Data

extension Exercise {
    static let mockExercises: [Exercise] = [
        Exercise(
            type: .multipleChoiceTranslate,
            prompt: "What does 'mirëdita' mean?",
            correctAnswer: "good day / hello",
            distractors: ["good night", "goodbye", "please"],
            explanation: "'Mirëdita' literally means 'good day' and is the standard daytime greeting.",
            xpValue: 10
        ),
        Exercise(
            type: .multipleChoiceTranslate,
            prompt: "How do you say 'thank you' in Albanian?",
            correctAnswer: "faleminderit",
            distractors: ["mirupafshim", "ju lutem", "po"],
            xpValue: 10
        ),
        Exercise(
            type: .translateTextInput,
            prompt: "Translate: 'I have water'",
            correctAnswer: "kam ujë",
            hint: "Use 'kam' for 'I have'",
            explanation: "'Kam' means 'I have' (1st person singular of the verb 'to have').",
            xpValue: 15
        ),
        Exercise(
            type: .fillInBlank,
            prompt: "Unë ___ student. (I am a student)",
            correctAnswer: "jam",
            distractors: ["kam", "dua", "flas"],
            explanation: "'Jam' means 'I am'. Albanian verb 'to be' is 'jam/je/është'.",
            xpValue: 10
        ),
    ]
}
