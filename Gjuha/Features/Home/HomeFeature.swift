import ComposableArchitecture
import Foundation

@Reducer
struct HomeFeature {
    @ObservableState
    struct State: Equatable {
        var units: [LearningUnit] = []
        var dueReviewCount: Int = 0
        var isLoading: Bool = false
        /// The whole stats record rather than a streak and an XP total.
        ///
        /// Home now shows progress toward today's goal, which needs `xpToday`
        /// and `dailyGoalXP` as well, and passing four loose integers around was
        /// how the header and Profile ended up able to disagree about the same
        /// numbers.
        var stats: UserStats = .empty

        var currentStreak: Int { stats.currentStreak }
        var totalXP: Int { stats.totalXP }
    }

    enum Action {
        case onAppear
        case unitsLoaded([LearningUnit])
        case lessonTapped(LessonSummary)
        case startReviewTapped
        case exploreCultureTapped
        case refreshAfterLessonComplete
        case statsLoaded(UserStats)
        case dueReviewsLoaded(Int)
    }

    @Dependency(\.curriculumRepository) var curriculumRepository
    @Dependency(\.progressRepository) var progressRepository
    @Dependency(\.reviewRepository) var reviewRepository

    var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .onAppear:
                guard !state.isLoading, state.units.isEmpty else { return .none }
                state.isLoading = true
                return .run { send in
                    let units = await curriculumRepository.fetchUnits()
                    await send(.unitsLoaded(units))
                    await send(.statsLoaded(await progressRepository.fetchUserStats()))
                    await send(.dueReviewsLoaded(reviewRepository.dueCount()))
                }

            case .unitsLoaded(let units):
                state.units = units
                state.isLoading = false
                return .none

            case .statsLoaded(let stats):
                state.stats = stats
                return .none

            case .dueReviewsLoaded(let count):
                state.dueReviewCount = count
                return .none

            case .lessonTapped:
                return .none

            case .startReviewTapped:
                // Handled by AppFeature, which pushes the review session.
                return .none

            case .exploreCultureTapped:
                // Handled by AppFeature, which pushes the culture hub.
                return .none

            case .refreshAfterLessonComplete:
                // Force reload units from repository (re-reads UserDefaults completion state)
                // The CurriculumRepository is init'd once, so we need a fresh read
                return .run { send in
                    // Re-init the repository to pick up new completion state
                    let freshRepo = LiveCurriculumRepository()
                    let units = await freshRepo.fetchUnits()
                    await send(.unitsLoaded(units))
                    await send(.statsLoaded(await progressRepository.fetchUserStats()))
                    await send(.dueReviewsLoaded(reviewRepository.dueCount()))
                }
            }
        }
    }
}
