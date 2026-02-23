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
        var hasBootstrappedData: Bool = false
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
        case bootstrapData
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
                return .send(.bootstrapData)

            case .home(.lessonTapped(let lesson)):
                // Don't open locked lessons
                guard !lesson.isLocked else { return .none }
                state.path.append(.lesson(LessonFeature.State(lesson: lesson)))
                return .none

            case .path(.element(id: _, action: .lesson(.exitTapped))):
                if !state.path.isEmpty {
                    state.path.removeLast()
                }
                // Refresh home to show updated completion/unlock state
                return .send(.home(.refreshAfterLessonComplete))

            case .path(.element(id: _, action: .lesson(.lessonCompleted))):
                // Will be handled when user exits
                return .none

            case .tabSelected(let tab):
                state.selectedTab = tab
                return .none

            case .bootstrapData:
                guard !state.hasBootstrappedData else { return .none }
                state.hasBootstrappedData = true
                return .merge(
                    .send(.home(.onAppear)),
                    .send(.vocabulary(.onAppear)),
                    .send(.grammar(.onAppear))
                )

            case .onboarding, .home, .vocabulary, .grammar, .profile, .path:
                return .none
            }
        }
        .forEach(\.path, action: \.path)
    }
}
