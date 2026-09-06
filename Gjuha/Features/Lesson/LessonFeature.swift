import ComposableArchitecture
import Foundation

@Reducer
struct LessonFeature {
    @ObservableState
    struct State: Equatable {
        var lesson: LessonSummary
        var exercises: [Exercise] = []
        var currentIndex: Int = 0
        var hearts: Int = 3
        var xpEarned: Int = 0
        var phase: Phase = .loading
        var answerResult: AnswerResult?
        var selectedAnswer: String?
        var combo: Int = 0

        enum Phase: Equatable {
            case loading
            case inProgress
            case completed(xp: Int)
            case failed
        }

        var currentExercise: Exercise? {
            guard currentIndex < exercises.count else { return nil }
            return exercises[currentIndex]
        }

        var progress: Double {
            guard !exercises.isEmpty else { return 0 }
            return Double(currentIndex) / Double(exercises.count)
        }
    }

    enum Action {
        case onAppear
        case exercisesLoaded([Exercise])
        case answerSubmitted(String)
        case answerFeedbackDismissed
        case nextExercise
        case lessonCompleted
        case lessonFailed
        case exitTapped
    }

    @Dependency(\.exerciseEngine) var exerciseEngine
    @Dependency(\.progressRepository) var progressRepository
    @Dependency(\.continuousClock) var clock

    var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .onAppear:
                state.phase = .loading
                state.currentIndex = 0
                state.hearts = 3
                state.xpEarned = 0
                state.combo = 0
                state.answerResult = nil
                state.selectedAnswer = nil
                return .run { [lesson = state.lesson] send in
                    let exercises = await exerciseEngine.generateExercises(for: lesson)
                    await send(.exercisesLoaded(exercises))
                }

            case .exercisesLoaded(let exercises):
                state.exercises = exercises
                state.phase = .inProgress
                return .none

            case .answerSubmitted(let answer):
                guard let current = state.currentExercise else { return .none }
                guard state.answerResult == nil else { return .none }
                state.selectedAnswer = answer

                switch exerciseEngine.grade(answer, for: current) {
                case .correct:
                    state.combo += 1
                    // Combo bonus: +5 XP for every 3 correct in a row.
                    let comboBonus = state.combo % 3 == 0 ? 5 : 0
                    let awarded = current.xpValue + comboBonus
                    state.xpEarned += awarded
                    state.answerResult = .correct(
                        xpAwarded: awarded,
                        explanation: current.explanation
                    )
                case .nearMiss:
                    // Recognised but not accepted: no XP, distinct feedback.
                    state.hearts -= 1
                    state.combo = 0
                    state.answerResult = .nearMiss(
                        correctAnswer: current.correctAnswer,
                        explanation: current.explanation
                    )
                case .incorrect:
                    state.hearts -= 1
                    state.combo = 0
                    state.answerResult = .wrong(
                        correctAnswer: current.correctAnswer,
                        explanation: current.explanation
                    )
                }

                // Auto-advance after delay
                return .run { send in
                    try await clock.sleep(for: .milliseconds(1400))
                    await send(.answerFeedbackDismissed)
                }

            case .answerFeedbackDismissed:
                let wasCorrect = state.answerResult?.isCorrect ?? false
                state.answerResult = nil
                state.selectedAnswer = nil

                if wasCorrect {
                    return .send(.nextExercise)
                } else if state.hearts <= 0 {
                    return .send(.lessonFailed)
                }
                return .none

            case .nextExercise:
                if state.currentIndex + 1 >= state.exercises.count {
                    return .send(.lessonCompleted)
                }
                state.currentIndex += 1
                return .none

            case .lessonCompleted:
                let xp = state.xpEarned
                state.phase = .completed(xp: xp)
                return .run { [lesson = state.lesson, xp] _ in
                    await progressRepository.markLessonCompleted(
                        lesson.id,
                        seedId: lesson.seedId,
                        xpEarned: xp
                    )
                }

            case .lessonFailed:
                state.phase = .failed
                return .none

            case .exitTapped:
                return .none
            }
        }
    }
}
