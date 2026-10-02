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

        /// Non nil when this session is a spaced repetition review over these due
        /// word ids, rather than a course lesson. A review does not mark a lesson
        /// complete or affect unlock state; it reschedules each word and counts as
        /// daily activity for the streak.
        var reviewWordIds: [String]?
        /// Maps a generated review exercise to the stable word id it exercises, so
        /// the outcome is recorded against the right schedule entry.
        var reviewWordByExerciseId: [UUID: String] = [:]

        var isReview: Bool { reviewWordIds != nil }

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
        case reviewExercisesLoaded([ReviewExercise])
        case answerSubmitted(String)
        case answerFeedbackDismissed
        case nextExercise
        case lessonCompleted
        case lessonFailed
        case exitTapped
        case playAudioTapped
    }

    @Dependency(\.exerciseEngine) var exerciseEngine
    @Dependency(\.progressRepository) var progressRepository
    @Dependency(\.reviewRepository) var reviewRepository
    @Dependency(\.audioPlayer) var audioPlayer
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
                if let wordIds = state.reviewWordIds {
                    return .run { send in
                        let items = await exerciseEngine.reviewExercises(forWordIds: wordIds)
                        await send(.reviewExercisesLoaded(items))
                    }
                }
                return .run { [lesson = state.lesson] send in
                    let exercises = await exerciseEngine.generateExercises(for: lesson)
                    await send(.exercisesLoaded(exercises))
                }

            case .exercisesLoaded(let exercises):
                state.exercises = exercises
                state.phase = .inProgress
                return .none

            case .reviewExercisesLoaded(let items):
                state.exercises = items.map(\.exercise)
                state.reviewWordByExerciseId = Dictionary(
                    uniqueKeysWithValues: items.map { ($0.exercise.id, $0.wordId) }
                )
                state.phase = .inProgress
                return .none

            case .answerSubmitted(let answer):
                guard let current = state.currentExercise else { return .none }
                guard state.answerResult == nil else { return .none }
                state.selectedAnswer = answer

                let grade = exerciseEngine.grade(answer, for: current)
                switch grade {
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
                    // Recognised but not accepted: no XP, distinct feedback. When
                    // the miss is a dropped diacritic, prepend a hint tied to the
                    // exact answer the learner typed. A review never ends on hearts,
                    // so hearts only drop in a course lesson.
                    if !state.isReview { state.hearts -= 1 }
                    state.combo = 0
                    let hint = AnswerNormalizer.diacriticHint(
                        submitted: answer,
                        correctAnswer: current.correctAnswer
                    )
                    let explanation = [hint, current.explanation]
                        .compactMap { $0 }
                        .joined(separator: "\n")
                    state.answerResult = .nearMiss(
                        correctAnswer: current.correctAnswer,
                        explanation: explanation.isEmpty ? nil : explanation
                    )
                case .incorrect:
                    if !state.isReview { state.hearts -= 1 }
                    state.combo = 0
                    state.answerResult = .wrong(
                        correctAnswer: current.correctAnswer,
                        explanation: current.explanation
                    )
                }

                // In a review, reschedule the word from this outcome. Mapping is
                // kept honest: correct -> good, near miss -> hard, wrong -> again.
                var reviewEffect: Effect<Action> = .none
                if state.isReview, let wordId = state.reviewWordByExerciseId[current.id] {
                    let reviewGrade: ReviewGrade
                    switch grade {
                    case .correct: reviewGrade = .good
                    case .nearMiss: reviewGrade = .hard
                    case .incorrect: reviewGrade = .again
                    }
                    reviewEffect = .run { _ in
                        await reviewRepository.recordOutcome(wordId: wordId, grade: reviewGrade)
                    }
                }

                // Auto-advance after delay
                return .merge(
                    reviewEffect,
                    .run { send in
                        try await clock.sleep(for: .milliseconds(1400))
                        await send(.answerFeedbackDismissed)
                    }
                )

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
                // A review session reschedules its words as the learner answers, so
                // on completion it only needs to count as daily activity. It must not
                // mark a course lesson complete or touch unlock state.
                if state.isReview {
                    return .run { _ in await progressRepository.updateStreak() }
                }
                return .run { [lesson = state.lesson, xp] _ in
                    await progressRepository.markLessonCompleted(
                        lesson.id,
                        seedId: lesson.seedId,
                        xpEarned: xp
                    )
                    // Newly learned words enter the spaced repetition schedule. Words
                    // already scheduled keep their existing progress.
                    let wordIds = LessonVocabularyMap.wordIds(
                        for: lesson.seedId,
                        lessonTitle: lesson.title
                    )
                    await reviewRepository.scheduleNewWords(wordIds)
                }

            case .lessonFailed:
                state.phase = .failed
                return .none

            case .exitTapped:
                return .none

            case .playAudioTapped:
                guard let exercise = state.currentExercise else { return .none }
                let url = exercise.audioFileName.flatMap { AudioLibrary.shared.url(forFile: $0) }
                let spoken = exercise.correctAnswer
                return .run { _ in
                    await audioPlayer.playOrSpeak(url: url, albanianText: spoken)
                }
            }
        }
    }
}
