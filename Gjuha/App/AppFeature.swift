import ComposableArchitecture
import SwiftUI

@Reducer
struct AppFeature {
    @ObservableState
    struct State: Equatable {
        var path = StackState<Path.State>()
        var home = HomeFeature.State()
        var hasCompletedOnboarding: Bool = false
    }

    enum Action {
        case path(StackActionOf<Path>)
        case home(HomeFeature.Action)
        case onboardingCompleted
    }

    @Reducer
    enum Path {
        case lesson(LessonFeature)
        case vocabulary(VocabularyFeature)
        case grammar(GrammarFeature)
        case profile(ProfileFeature)
    }

    var body: some ReducerOf<Self> {
        Scope(state: \.home, action: \.home) {
            HomeFeature()
        }
        Reduce { state, action in
            switch action {
            case .onboardingCompleted:
                state.hasCompletedOnboarding = true
                return .none
            case .home, .path:
                return .none
            }
        }
        .forEach(\.path, action: \.path)
    }
}
