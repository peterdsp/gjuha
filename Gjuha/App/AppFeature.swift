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
        case startReviewSession([String])
    }

    @Reducer
    enum Path {
        case lesson(LessonFeature)
        case vocabulary(VocabularyFeature)
        case grammar(GrammarFeature)
        case profile(ProfileFeature)
    }

    @Dependency(\.progressRepository) var progressRepository
    @Dependency(\.reviewRepository) var reviewRepository

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
                let chosenGoal = state.onboarding.selectedGoal
                state.profile.selectedGoal = chosenGoal
                UserDefaults.standard.set(true, forKey: Keys.hasCompletedOnboarding)
                return .merge(
                    .run { _ in await progressRepository.saveLearningGoal(chosenGoal) },
                    .send(.bootstrapData)
                )

            case .home(.lessonTapped(let lesson)):
                // Don't open locked lessons
                guard !lesson.isLocked else { return .none }
                state.path.append(.lesson(LessonFeature.State(lesson: lesson)))
                return .none

            case .home(.startReviewTapped):
                // Fetch the due words off the store, then push the review session.
                return .run { send in
                    let ids = await reviewRepository.dueWordIds(limit: 20)
                    await send(.startReviewSession(ids))
                }

            case .startReviewSession(let wordIds):
                guard !wordIds.isEmpty else { return .none }
                let reviewLesson = LessonSummary(
                    seedId: "review-session",
                    title: "Daily Review",
                    subtitle: "Spaced repetition",
                    iconName: "arrow.triangle.2.circlepath",
                    lessonType: .review
                )
                state.path.append(.lesson(
                    LessonFeature.State(lesson: reviewLesson, reviewWordIds: wordIds)
                ))
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

            case .profile(.resetCompleted):
                // A reset wiped progress and the review schedule. Refresh Home so its
                // cached units, unlock state, stats, and due reviews reflect the wipe
                // instead of showing stale completed lessons until the next launch.
                return .send(.home(.refreshAfterLessonComplete))

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
