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
    }

    @Dependency(\.curriculumRepository) var curriculumRepository

    var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .onAppear:
                guard !state.isLoading, state.units.isEmpty else { return .none }
                state.isLoading = true
                return .run { send in
                    let units = await curriculumRepository.fetchUnits()
                    await send(.unitsLoaded(units))
                }
            case .unitsLoaded(let units):
                state.units = units
                state.isLoading = false
                return .none
            case .lessonTapped:
                return .none
            }
        }
    }
}
