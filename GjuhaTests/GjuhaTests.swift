import Testing
import Foundation
@testable import Gjuha

// Phase 0 regression tests.
//
// These are pure logic tests against the Gjuha module (resolved through the test
// host). They deliberately avoid TCA's `TestStore`: in this Xcode / TCA
// toolchain a test bundle that statically links ComposableArchitecture fails to
// resolve swift-navigation symbols. The reducers are thin wrappers over the
// logic exercised here (option ordering, grading, distractors, goal storage,
// progress math), which is where the Phase 0 defects lived.
struct GjuhaTests {

    // MARK: - Stable option ordering

    @Test
    func optionOrderIsStableAcrossRepeatedReads() {
        let exercise = Exercise(
            type: .multipleChoiceTranslate,
            prompt: "What does 'po' mean?",
            correctAnswer: "yes",
            distractors: ["no", "please", "water"]
        )
        let firstRead = exercise.orderedOptions
        // Reading many times must never reshuffle (the old computed `allOptions` bug).
        for _ in 0..<100 {
            #expect(exercise.orderedOptions == firstRead)
        }
        #expect(firstRead.count == 4)
        #expect(Set(firstRead) == ["yes", "no", "please", "water"])
    }

    @Test
    func optionListDeduplicatesAndKeepsCorrectAnswer() {
        // Distractors that collide with the answer or each other must be dropped.
        let exercise = Exercise(
            type: .multipleChoiceTranslate,
            prompt: "p",
            correctAnswer: "yes",
            distractors: ["yes", "No", "no", "please"]
        )
        let options = exercise.orderedOptions
        #expect(options.contains("yes"))
        #expect(options.filter { $0.lowercased() == "yes" }.count == 1)
        #expect(options.filter { $0.lowercased() == "no" }.count == 1)
        // "yes", "no", "please" survive de-duplication.
        #expect(options.count == 3)
    }

    @Test
    func explicitOptionOrderIsRetainedVerbatim() {
        // When the engine supplies a fixed order, the model stores it unchanged.
        let order = ["please", "yes", "water", "no"]
        let exercise = Exercise(
            type: .multipleChoiceTranslate,
            prompt: "p",
            correctAnswer: "yes",
            distractors: ["no", "please", "water"],
            orderedOptions: order
        )
        #expect(exercise.orderedOptions == order)
        #expect(exercise.orderedOptions == order) // still stable on a second read
    }

    // MARK: - Grading boundaries

    @Test
    func gradingAcceptsExactCaseWhitespaceAndUnicodeVariants() {
        let engine = ExerciseEngine()

        #expect(engine.grade("faleminderit", for: Self.typed("faleminderit")) == .correct)
        // Case and surrounding / internal whitespace are normalised.
        #expect(engine.grade("  Faleminderit  ", for: Self.typed("faleminderit")) == .correct)
        #expect(engine.grade("ju    lutem", for: Self.typed("ju lutem")) == .correct)

        // Unicode: a decomposed ë (e + combining diaeresis) is still accepted.
        // (Swift's String compares by canonical equivalence, so the raw bytes
        // differ even though the values are equal; grading must accept it.)
        let correct = "përshëndetje"
        let decomposedInput = correct.decomposedStringWithCanonicalMapping
        #expect(Array(decomposedInput.unicodeScalars) != Array(correct.unicodeScalars)) // the scalars really differ
        #expect(engine.grade(decomposedInput, for: Self.typed(correct)) == .correct)
    }

    @Test
    func gradingAcceptsAlternateAndGlossForms() {
        let engine = ExerciseEngine()
        // "x / y" style answers accept either side.
        #expect(engine.grade("hello", for: Self.typed("good day / hello")) == .correct)
        #expect(engine.grade("good day", for: Self.typed("good day / hello")) == .correct)
        // A trailing parenthetical gloss is optional.
        #expect(engine.grade("to be", for: Self.typed("to be (1st sg)")) == .correct)
    }

    @Test
    func gradingDoesNotAcceptDroppedDiacriticsButFlagsNearMiss() {
        let engine = ExerciseEngine()

        // Dropping ë or ç changes meaning: never accepted as correct...
        #expect(engine.grade("pershendetje", for: Self.typed("përshëndetje")) != .correct)
        #expect(engine.grade("caj", for: Self.typed("çaj")) != .correct)
        // ...but recognised as a near miss for targeted feedback.
        #expect(engine.grade("pershendetje", for: Self.typed("përshëndetje")) == .nearMiss)
        #expect(engine.grade("caj", for: Self.typed("çaj")) == .nearMiss)
        // The properly accented answer is correct.
        #expect(engine.grade("çaj", for: Self.typed("çaj")) == .correct)
    }

    @Test
    func gradingDistinguishesTyposFromWrongAnswers() {
        let engine = ExerciseEngine()

        // Single typo in a long-enough word is a near miss.
        #expect(engine.grade("faleminderitt", for: Self.typed("faleminderit")) == .nearMiss)
        // A different word is simply incorrect.
        #expect(engine.grade("mirëdita", for: Self.typed("faleminderit")) == .incorrect)
        // Short words get no typo leniency (po vs jo are distinct).
        #expect(engine.grade("jo", for: Self.typed("po")) == .incorrect)
    }

    @Test
    func nearMissAppliesOnlyToTypedAnswersNotMultipleChoice() {
        let engine = ExerciseEngine()
        // On multiple choice, a diacritic variant of a tapped option is not a
        // "near miss": you pick an option, so anything but the answer is wrong.
        let mcq = Exercise(
            type: .multipleChoiceTranslate,
            prompt: "p",
            correctAnswer: "çaj",
            distractors: ["caj", "ujë", "bukë"]
        )
        #expect(engine.grade("caj", for: mcq) == .incorrect)
        #expect(engine.grade("çaj", for: mcq) == .correct)
    }

    @Test
    func checkAnswerConvenienceMatchesGrade() {
        let engine = ExerciseEngine()
        #expect(engine.checkAnswer("çaj", for: Self.typed("çaj")))
        #expect(!engine.checkAnswer("caj", for: Self.typed("çaj"))) // near miss is not "correct"
    }

    // MARK: - Distractor validity

    @Test
    func generatedDistractorsAreValidUniqueAndNonAmbiguous() async {
        let engine = ExerciseEngine()
        let lesson = LessonSummary(
            seedId: "L001",
            title: "Greetings",
            subtitle: "",
            iconName: "hand.wave.fill",
            lessonType: .vocabulary
        )
        let exercises = await engine.generateExercises(for: lesson)
        #expect(!exercises.isEmpty)

        for exercise in exercises where exercise.type == .multipleChoiceTranslate || exercise.type == .fillInBlank {
            let lowerOptions = exercise.orderedOptions.map { $0.lowercased() }
            // Options contain the correct answer, exactly once, plus distractors.
            #expect(exercise.orderedOptions.contains(exercise.correctAnswer))
            #expect(Set(lowerOptions).count == lowerOptions.count) // no duplicates
            #expect(exercise.distractors.count == 3)
            // No distractor is also the correct answer (would be ambiguous).
            #expect(!exercise.distractors.map { $0.lowercased() }.contains(exercise.correctAnswer.lowercased()))
        }
    }

    @Test
    func distractorsPreferSamePartOfSpeech() {
        let engine = ExerciseEngine()
        let target = Self.seed("n1", "libër", "book", pos: "noun", freq: 10)
        let sameNouns = (0..<5).map { Self.seed("n\($0 + 2)", "noun\($0)", "bookish\($0)", pos: "noun", freq: 11 + $0) }
        let verbs = (0..<5).map { Self.seed("v\($0)", "verb\($0)", "runs\($0)", pos: "verb", freq: 12 + $0) }
        let pool = [target] + sameNouns + verbs

        let distractors = engine.pickDistractors(for: target, from: pool, count: 3, useEnglish: true)
        #expect(distractors.count == 3)
        #expect(!distractors.contains("book"))
        #expect(Set(distractors).count == 3)
        // With enough same-part-of-speech options, all distractors are nouns.
        let nounEnglish = Set(sameNouns.map { $0.english })
        #expect(distractors.allSatisfy { nounEnglish.contains($0) })
    }

    @Test
    func distractorsExcludeSynonymsThatWouldAlsoBeCorrect() {
        let engine = ExerciseEngine()
        let target = Self.seed("w1", "mirëdita", "good day / hello", pos: "interjection", freq: 1)
        // A candidate whose gloss overlaps ("hello") must not become a distractor.
        let synonym = Self.seed("w2", "tungjatjeta", "hello", pos: "interjection", freq: 2)
        let safe = Self.seed("w3", "mirupafshim", "goodbye", pos: "interjection", freq: 3)
        let pool = [target, synonym, safe]

        let distractors = engine.pickDistractors(for: target, from: pool, count: 3, useEnglish: true)
        #expect(!distractors.contains("hello"))
        #expect(distractors.contains("goodbye"))
    }

    @Test
    func distractorsFallBackSafelyWhenPoolIsTooSmall() {
        let engine = ExerciseEngine()
        let target = Self.seed("n1", "libër", "book", pos: "noun", freq: 10)
        // Only the target in the pool: must still produce 3 usable, unique options.
        let distractors = engine.pickDistractors(for: target, from: [target], count: 3, useEnglish: true)
        #expect(distractors.count == 3)
        #expect(!distractors.contains("book"))
        #expect(Set(distractors).count == 3)
    }

    // MARK: - Goal persistence

    @Test
    func learningGoalPersistsAndRestores() {
        let suiteName = "gjuha.test.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let store = ProgressStore(defaults: defaults)
        #expect(store.learningGoalRawValue == nil) // nothing chosen yet

        store.setLearningGoal(LearningGoal.serious.rawValue)
        #expect(store.learningGoalRawValue == "serious")

        // A fresh store over the same defaults restores the saved goal.
        let restored = ProgressStore(defaults: defaults)
        #expect(LearningGoal(rawValue: restored.learningGoalRawValue ?? "") == .serious)
    }

    // MARK: - Progress calculations

    @Test
    func wordsSeenCountsDistinctVocabularyFromCompletedLessons() {
        // No completed lessons: honestly zero (not a fabricated multiple).
        #expect(LiveProgressRepository.wordsSeen(in: []) == 0)

        // A completed lesson contributes exactly its mapped vocabulary.
        let l001 = Set(LessonVocabularyMap.wordIds(for: "L001", lessonTitle: ""))
        #expect(l001.isEmpty == false)
        #expect(LiveProgressRepository.wordsSeen(in: ["L001"]) == l001.count)

        // Overlapping lessons are de-duplicated (a union, not a sum).
        let l040 = Set(LessonVocabularyMap.wordIds(for: "L040", lessonTitle: ""))
        let expectedUnion = l001.union(l040).count
        #expect(LiveProgressRepository.wordsSeen(in: ["L001", "L040"]) == expectedUnion)
        // Union must not exceed the naive sum, and dedupes when lessons share words.
        #expect(expectedUnion <= l001.count + l040.count)
    }

    // MARK: - Fixtures

    static func typed(_ correct: String) -> Exercise {
        Exercise(type: .translateTextInput, prompt: "Translate", correctAnswer: correct)
    }

    static func seed(_ id: String, _ albanian: String, _ english: String, pos: String, freq: Int) -> SeedWordEntry {
        SeedWordEntry(
            id: id,
            albanian: albanian,
            english: english,
            cefrLevel: "a1",
            partOfSpeech: pos,
            gender: nil,
            verbClass: nil,
            exampleSentence: nil,
            exampleTranslation: nil,
            frequency: freq
        )
    }
}
