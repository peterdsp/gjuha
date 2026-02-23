import ComposableArchitecture
import Foundation

@Reducer
struct HomeFeature {
    @ObservableState
    struct State: Equatable {
        var units: [LearningUnit] = []
        var currentStreak: Int = 0
        var totalXP: Int = 0
        var isLoading: Bool = false
    }

    enum Action {
        case onAppear
        case unitsLoaded([LearningUnit])
        case lessonTapped(LessonSummary)
        case refreshAfterLessonComplete
        case statsLoaded(streak: Int, xp: Int)
    }

    @Dependency(\.curriculumRepository) var curriculumRepository
    @Dependency(\.progressRepository) var progressRepository

    var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .onAppear:
                guard !state.isLoading, state.units.isEmpty else { return .none }
                state.isLoading = true
                return .run { send in
                    let units = await curriculumRepository.fetchUnits()
                    await send(.unitsLoaded(units))
                    let streak = await progressRepository.fetchCurrentStreak()
                    let xp = await progressRepository.fetchTotalXP()
                    await send(.statsLoaded(streak: streak, xp: xp))
                }

            case .unitsLoaded(let units):
                state.units = units
                state.isLoading = false
                return .none

            case .statsLoaded(let streak, let xp):
                state.currentStreak = streak
                state.totalXP = xp
                return .none

            case .lessonTapped:
                return .none

            case .refreshAfterLessonComplete:
                // Force reload units from repository (re-reads UserDefaults completion state)
                // The CurriculumRepository is init'd once, so we need a fresh read
                return .run { send in
                    // Re-init the repository to pick up new completion state
                    let freshRepo = LiveCurriculumRepository()
                    let units = await freshRepo.fetchUnits()
                    await send(.unitsLoaded(units))
                    let store = ProgressStore.shared
                    await send(.statsLoaded(streak: store.currentStreak, xp: store.totalXP))
                }
            }
        }
    }
}
