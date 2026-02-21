import Foundation
import Dependencies

// MARK: - Protocol

protocol ExerciseEngineProtocol {
    func generateExercises(for lesson: Lesson) async -> [Exercise]
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

// MARK: - Live Engine

final class ExerciseEngine: ExerciseEngineProtocol {
    func generateExercises(for lesson: Lesson) async -> [Exercise] {
        switch lesson.lessonType {
        case .vocabulary:
            return await generateVocabularyExercises(lesson)
        case .grammar:
            return await generateGrammarExercises(lesson)
        case .review:
            return await generateReviewExercises(lesson)
        default:
            return []
        }
    }

    func checkAnswer(_ answer: String, for exercise: Exercise) -> Bool {
        let normalizedAnswer = answer.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let normalizedCorrect = exercise.correctAnswer.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return normalizedAnswer == normalizedCorrect
    }

    private func generateVocabularyExercises(_ lesson: Lesson) async -> [Exercise] {
        // TODO: Load words for lesson, generate MCQ + translation exercises
        // Engine generates varied exercise types from the same word pool
        return Exercise.mockExercises
    }

    private func generateGrammarExercises(_ lesson: Lesson) async -> [Exercise] {
        // TODO: Load grammar topic, generate conjugation + fill-in-blank exercises
        return []
    }

    private func generateReviewExercises(_ lesson: Lesson) async -> [Exercise] {
        // TODO: SRS-based selection of words due for review
        return []
    }
}

// MARK: - Mock Engine

final class MockExerciseEngine: ExerciseEngineProtocol {
    func generateExercises(for lesson: Lesson) async -> [Exercise] {
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
            correctAnswer: "good day",
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
