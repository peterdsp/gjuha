import Foundation
import SwiftData

@Model
final class Word {
    var id: UUID
    var albanian: String
    var english: String
    var cefrLevel: CEFRLevel
    var partOfSpeech: PartOfSpeech
    var gender: NounGender?
    var verbClass: VerbClass?
    var exampleSentence: String?
    var exampleTranslation: String?
    var audioFileName: String?
    var frequency: Int
    var isLearned: Bool
    var lastReviewedAt: Date?

    init(
        id: UUID = UUID(),
        albanian: String,
        english: String,
        cefrLevel: CEFRLevel,
        partOfSpeech: PartOfSpeech,
        gender: NounGender? = nil,
        verbClass: VerbClass? = nil,
        exampleSentence: String? = nil,
        exampleTranslation: String? = nil,
        audioFileName: String? = nil,
        frequency: Int = 0
    ) {
        self.id = id
        self.albanian = albanian
        self.english = english
        self.cefrLevel = cefrLevel
        self.partOfSpeech = partOfSpeech
        self.gender = gender
        self.verbClass = verbClass
        self.exampleSentence = exampleSentence
        self.exampleTranslation = exampleTranslation
        self.audioFileName = audioFileName
        self.frequency = frequency
        self.isLearned = false
        self.lastReviewedAt = nil
    }
}

enum CEFRLevel: String, Codable, CaseIterable {
    case a1, a2, b1, b2, c1, c2
}

enum PartOfSpeech: String, Codable, CaseIterable {
    case noun
    case verb
    case adjective
    case adverb
    case pronoun
    case preposition
    case conjunction
    case interjection
    case numeral
    case particle
}

enum NounGender: String, Codable, CaseIterable {
    case masculine = "m"
    case feminine = "f"
    case neuter = "n"
}

enum VerbClass: String, Codable, CaseIterable {
    case firstConjugation   // -oj verbs (e.g., punoj)
    case secondConjugation  // -ej/-ij verbs
    case thirdConjugation   // -j verbs with stem alternation
    case irregular
}
