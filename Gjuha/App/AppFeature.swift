import ComposableArchitecture
import SwiftUI

@Reducer
struct AppFeature {
    private enum Keys {
        static let hasCompletedOnboarding = "hasCompletedOnboarding"
    }

    @ObservableState
    struct State {
        enum RootTab: Hashable {
            case home
            case vocabulary
            case grammar
            case profile
        }

        var path = StackState<Path.State>()
        var onboarding = OnboardingFeature.State()
        var home = HomeFeature.State()
        var vocabulary = VocabularyFeature.State()
        var grammar = GrammarFeature.State()
        var profile = ProfileFeature.State()
        var selectedTab: RootTab = .home
        var hasCompletedOnboarding: Bool = UserDefaults.standard.bool(forKey: Keys.hasCompletedOnboarding)
    }

    enum Action {
        case path(StackActionOf<Path>)
        case onboarding(OnboardingFeature.Action)
        case home(HomeFeature.Action)
        case vocabulary(VocabularyFeature.Action)
        case grammar(GrammarFeature.Action)
        case profile(ProfileFeature.Action)
        case onboardingCompleted
        case tabSelected(State.RootTab)
    }

    @Reducer
    enum Path {
        case lesson(LessonFeature)
        case vocabulary(VocabularyFeature)
        case grammar(GrammarFeature)
        case profile(ProfileFeature)
    }

    var body: some ReducerOf<Self> {
        Scope(state: \.onboarding, action: \.onboarding) {
            OnboardingFeature()
        }
        Scope(state: \.home, action: \.home) {
            HomeFeature()
        }
        Scope(state: \.vocabulary, action: \.vocabulary) {
            VocabularyFeature()
        }
        Scope(state: \.grammar, action: \.grammar) {
            GrammarFeature()
        }
        Scope(state: \.profile, action: \.profile) {
            ProfileFeature()
        }
        Reduce { state, action in
            switch action {
            case .onboarding(.completed), .onboardingCompleted:
                state.hasCompletedOnboarding = true
                state.selectedTab = .home
                state.path = StackState<Path.State>()
                state.profile.selectedGoal = state.onboarding.selectedGoal
                UserDefaults.standard.set(true, forKey: Keys.hasCompletedOnboarding)
                return .none

            case .home(.lessonTapped(let lesson)):
                state.path.append(.lesson(LessonFeature.State(lesson: lesson)))
                return .none

            case .tabSelected(let tab):
                state.selectedTab = tab
                return .none

            case .onboarding, .home, .vocabulary, .grammar, .profile, .path:
                return .none
            }
        }
        .forEach(\.path, action: \.path)
    }
}
