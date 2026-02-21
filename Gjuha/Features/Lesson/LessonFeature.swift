import ComposableArchitecture
import Foundation

@Reducer
struct LessonFeature {
    @ObservableState
    struct State: Equatable {
        var lesson: Lesson
        var exercises: [Exercise] = []
        var currentIndex: Int = 0
        var hearts: Int = 3
        var xpEarned: Int = 0
        var phase: Phase = .loading

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
        case nextExercise
        case lessonCompleted
        case lessonFailed
        case exitTapped
    }

    @Dependency(\.exerciseEngine) var exerciseEngine
    @Dependency(\.progressRepository) var progressRepository

    var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .onAppear:
                state.phase = .loading
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
                let isCorrect = exerciseEngine.checkAnswer(answer, for: current)
                if isCorrect {
                    state.xpEarned += current.xpValue
                    return .send(.nextExercise)
                } else {
                    state.hearts -= 1
                    if state.hearts <= 0 {
                        return .send(.lessonFailed)
                    }
                    return .none
                }

            case .nextExercise:
                if state.currentIndex + 1 >= state.exercises.count {
                    return .send(.lessonCompleted)
                }
                state.currentIndex += 1
                return .none

            case .lessonCompleted:
                let xp = state.xpEarned
                state.phase = .completed(xp: xp)
                return .run { [lessonId = state.lesson.id, xp] _ in
                    await progressRepository.markLessonCompleted(lessonId, xpEarned: xp)
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
