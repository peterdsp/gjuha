import Foundation

struct Exercise: Identifiable, Equatable {
    let id: UUID
    let type: ExerciseType
    let prompt: String
    let correctAnswer: String
    let distractors: [String]
    let hint: String?
    let explanation: String?
    let xpValue: Int
    let wordId: UUID?

    init(
        id: UUID = UUID(),
        type: ExerciseType,
        prompt: String,
        correctAnswer: String,
        distractors: [String] = [],
        hint: String? = nil,
        explanation: String? = nil,
        xpValue: Int = 10,
        wordId: UUID? = nil
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
    }

    /// All answer options (correct + distractors) in shuffled order
    var allOptions: [String] {
        ([correctAnswer] + distractors).shuffled()
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

/// Result of checking an answer — used for feedback UI
enum AnswerResult: Equatable {
    case correct
    case wrong(correctAnswer: String)
}
