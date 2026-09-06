import ComposableArchitecture
import Foundation

@Reducer
struct ProfileFeature {
    @ObservableState
    struct State: Equatable {
        var stats: UserStats = .empty
        var selectedGoal: LearningGoal = .casual
        var isLoading: Bool = false
    }

    enum Action {
        case onAppear
        case statsLoaded(UserStats)
        case goalLoaded(LearningGoal)
        case goalChanged(LearningGoal)
    }

    @Dependency(\.progressRepository) var progressRepository

    var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .onAppear:
                state.isLoading = true
                return .run { send in
                    let stats = await progressRepository.fetchUserStats()
                    await send(.statsLoaded(stats))
                    let goal = await progressRepository.fetchLearningGoal()
                    await send(.goalLoaded(goal))
                }
            case .statsLoaded(let stats):
                state.stats = stats
                state.isLoading = false
                return .none
            case .goalLoaded(let goal):
                state.selectedGoal = goal
                return .none
            case .goalChanged(let goal):
                state.selectedGoal = goal
                return .run { _ in
                    await progressRepository.saveLearningGoal(goal)
                }
            }
        }
    }
}
