import Foundation

struct Exercise: Identifiable, Equatable, Codable {
    let id: UUID
    let type: ExerciseType
    let prompt: String
    let correctAnswer: String
    let distractors: [String]
    let hint: String?
    let explanation: String?
    let xpValue: Int
    let wordId: UUID?

    /// Pairs for a `wordMatch` exercise (Albanian ↔ English). Empty for other types.
    let pairs: [MatchPair]

    /// Manifest audio asset name (without extension) for a `tapWhatYouHear`
    /// exercise, or a prompt that can be spoken. `nil` when no audio is attached.
    let audioFileName: String?

    /// Answer options (correct + distractors) in a single, fixed order.
    ///
    /// The order is decided once, when the exercise is created, and then stored.
    /// Reading it never reshuffles, so the options keep their position for the
    /// whole lifetime of the exercise, including after feedback and unrelated
    /// state changes. This replaces the previous computed `allOptions`, which
    /// reshuffled on every access and made the buttons jump on each view update.
    let orderedOptions: [String]

    init(
        id: UUID = UUID(),
        type: ExerciseType,
        prompt: String,
        correctAnswer: String,
        distractors: [String] = [],
        hint: String? = nil,
        explanation: String? = nil,
        xpValue: Int = 10,
        wordId: UUID? = nil,
        pairs: [MatchPair] = [],
        audioFileName: String? = nil,
        orderedOptions: [String]? = nil
    ) {
        self.id = id
        self.type = type
        self.prompt = prompt
        self.correctAnswer = correctAnswer
        self.distractors = distractors
        self.hint = hint
        self.explanation = explanation
        self.xpValue = xpValue
        self.wordId = wordId
        self.pairs = pairs
        self.audioFileName = audioFileName
        self.orderedOptions = orderedOptions
            ?? Exercise.makeOrderedOptions(correctAnswer: correctAnswer, distractors: distractors)
    }

    /// Builds a de-duplicated, one-time-shuffled option list.
    /// De-duplication is case- and whitespace-insensitive and keeps the correct
    /// answer (it appears first in the input), guarding against a distractor that
    /// accidentally equals the answer.
    static func makeOrderedOptions(correctAnswer: String, distractors: [String]) -> [String] {
        var seen = Set<String>()
        var unique: [String] = []
        for option in [correctAnswer] + distractors {
            let key = option.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            guard !key.isEmpty, seen.insert(key).inserted else { continue }
            unique.append(option)
        }
        return unique.shuffled()
    }
}

enum ExerciseType: String, Codable, Equatable {
    case multipleChoiceTranslate  // Tap the correct translation
    case tapWhatYouHear           // Listen and select
    case translateTextInput       // Type the translation
    case wordMatch                // Match pairs
    case fillInBlank              // Complete the sentence
    case conjugationTable         // Fill in verb form
    case arrangeWords             // Put words in order
    case trueFalse                // Grammar statement T/F
}

/// One Albanian ↔ English pair inside a `wordMatch` exercise.
struct MatchPair: Identifiable, Equatable, Codable {
    let id: UUID
    let albanian: String
    let english: String

    init(id: UUID = UUID(), albanian: String, english: String) {
        self.id = id
        self.albanian = albanian
        self.english = english
    }
}

extension Exercise {
    /// Canonical, order independent serialization of matched pairs. The engine
    /// builds `correctAnswer` from the intended pairs with this function, and the
    /// matching view submits the learner's pairs through the same function, so
    /// grading is a plain string comparison that ignores the order the learner
    /// matched them in.
    static func matchAnswer(from pairs: [MatchPair]) -> String {
        pairs
            .map { "\(AnswerNormalizer.normalize($0.albanian))=\(AnswerNormalizer.normalize($0.english))" }
            .sorted()
            .joined(separator: "|")
    }
}

/// Outcome of grading a submitted answer.
///
/// `nearMiss` is deliberately distinct from `correct`: an answer that only
/// differs from the expected Albanian by diacritics (ë, ç) or a single typo is
/// recognised so the learner gets targeted feedback, but it is never accepted as
/// correct. Dropping ë/ç changes meaning and the skill being tested, so it does
/// not earn credit.
enum AnswerGrade: Equatable {
    case correct
    case nearMiss
    case incorrect
}

/// Result of checking an answer, used to drive the feedback UI.
/// Carries the real XP awarded and any explanation so the view can surface them.
enum AnswerResult: Equatable {
    case correct(xpAwarded: Int, explanation: String?)
    case nearMiss(correctAnswer: String, explanation: String?)
    case wrong(correctAnswer: String, explanation: String?)

    var isCorrect: Bool {
        if case .correct = self { return true }
        return false
    }

    /// The explanation to surface, regardless of outcome.
    var explanation: String? {
        switch self {
        case let .correct(_, explanation),
             let .nearMiss(_, explanation),
             let .wrong(_, explanation):
            return explanation
        }
    }
}
