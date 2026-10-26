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
        /// A deep link that arrived before the curriculum finished loading.
        ///
        /// Siri, Shortcuts, and a widget tap can all launch the app cold, in which
        /// case the link lands before `units` exist and there is nothing to open
        /// yet. Holding it here and resolving it on `unitsLoaded` is what makes a
        /// cold launch from a widget behave the same as a tap inside the app.
        var pendingDeepLink: GjuhaDeepLink?
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
        /// Something outside the app (Siri, Shortcuts, a widget tap) asked for an
        /// action. Everything external funnels through here.
        case deepLinkReceived(GjuhaDeepLink)
    }

    @Reducer
    enum Path {
        case lesson(LessonFeature)
        case vocabulary(VocabularyFeature)
        case grammar(GrammarFeature)
        case profile(ProfileFeature)
        case culture(CultureFeature)
        case culturalUnit(CulturalUnitFeature)
        case dialectPack(DialectPackFeature)
    }

    @Dependency(\.progressRepository) var progressRepository
    @Dependency(\.reviewRepository) var reviewRepository
    @Dependency(\.widgetSync) var widgetSync

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
                    .send(.bootstrapData),
                    .run { _ in await widgetSync.refresh() }
                )

            case .home(.lessonTapped(let lesson)):
                // Don't open locked lessons
                guard !lesson.isLocked else { return .none }
                state.path.append(.lesson(LessonFeature.State(lesson: lesson)))
                return .none

            case .home(.exploreCultureTapped):
                // Always reachable in production: the hub itself is real. Its
                // content is gated to natively reviewed items, so in a normal build
                // it shows an "in review" empty state rather than unreviewed language.
                state.path.append(.culture(CultureFeature.State()))
                return .none

            case let .path(.element(id: _, action: .culture(.unitTapped(unit)))):
                state.path.append(.culturalUnit(CulturalUnitFeature.State(unit: unit)))
                return .none

            case let .path(.element(id: _, action: .culture(.packTapped(pack)))):
                state.path.append(.dialectPack(DialectPackFeature.State(pack: pack)))
                return .none

            case let .path(.element(id: _, action: .culturalUnit(.practiceTapped(wordIds)))):
                // Practising a cultural unit runs the normal spaced repetition
                // session over the unit's words, so XP banking, streak credit, and
                // rescheduling all flow through the same honest retention machinery.
                guard !wordIds.isEmpty else { return .none }
                let practiceLesson = LessonSummary(
                    seedId: "culture-practice",
                    title: "Culture Practice",
                    subtitle: "Strengthen these words",
                    iconName: "globe.europe.africa.fill",
                    lessonType: .review
                )
                state.path.append(.lesson(
                    LessonFeature.State(lesson: practiceLesson, reviewWordIds: wordIds)
                ))
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
                // Refresh home to show updated completion/unlock state. Every
                // finished lesson and review leaves through here, so this is also
                // where the widget's projection is rebuilt.
                return .merge(
                    .send(.home(.refreshAfterLessonComplete)),
                    .run { _ in await widgetSync.refresh() }
                )

            case .path(.element(id: _, action: .lesson(.lessonCompleted))):
                // Will be handled when user exits
                return .none

            case .profile(.resetCompleted):
                // A reset wiped progress and the review schedule. Refresh Home so its
                // cached units, unlock state, stats, and due reviews reflect the wipe
                // instead of showing stale completed lessons until the next launch,
                // and rebuild the widget so it stops showing a deleted streak.
                return .merge(
                    .send(.home(.refreshAfterLessonComplete)),
                    .run { _ in await widgetSync.refresh() }
                )

            case .tabSelected(let tab):
                state.selectedTab = tab
                return .none

            case .bootstrapData:
                guard !state.hasBootstrappedData else { return .none }
                state.hasBootstrappedData = true
                // Durable resume: if the app was terminated mid course lesson, put
                // the learner back in it with the same questions, position, hearts,
                // XP, and combo. Only ever one saved course session; reviews are not
                // snapshotted. Restoring does not re-bank XP or reschedule, because
                // those happen only on completion.
                if state.path.isEmpty, let snapshot = LessonSessionStore.shared.load() {
                    state.path.append(.lesson(LessonFeature.State(restoredFrom: snapshot)))
                }
                return .merge(
                    .send(.home(.onAppear)),
                    .send(.vocabulary(.onAppear)),
                    .send(.grammar(.onAppear)),
                    .run { _ in await widgetSync.refresh() }
                )

            case .deepLinkReceived(let link):
                // Onboarding has to finish first: there is no progress to act on
                // and no lesson to open before it does.
                guard state.hasCompletedOnboarding else { return .none }
                guard !state.home.units.isEmpty else {
                    // Cold launch. Hold the link and resolve it once the
                    // curriculum is in state.
                    state.pendingDeepLink = link
                    return .send(.bootstrapData)
                }
                return Self.resolve(link, &state)

            case .home(.unitsLoaded):
                guard let link = state.pendingDeepLink else { return .none }
                state.pendingDeepLink = nil
                return Self.resolve(link, &state)

            case .onboarding, .home, .vocabulary, .grammar, .profile, .path:
                return .none
            }
        }
        .forEach(\.path, action: \.path)
    }

    /// Turns an external request into navigation.
    ///
    /// Every case bails out when something is already pushed on the path. That is
    /// deliberate: a lesson in progress is only ever discarded through the explicit
    /// confirmation in `LessonView`, so a widget tap or a Siri phrase must never
    /// throw away answered questions. If the learner is already in a lesson,
    /// bringing the app forward *is* the useful outcome.
    private static func resolve(_ link: GjuhaDeepLink, _ state: inout State) -> Effect<Action> {
        guard state.path.isEmpty else { return .none }

        switch link {
        case .startReview:
            return .send(.home(.startReviewTapped))

        case .continueLearning:
            guard let lesson = nextOpenableLesson(in: state.home.units) else {
                // Everything reachable is done. Land on Home rather than nowhere.
                state.selectedTab = .home
                return .none
            }
            state.selectedTab = .home
            state.path.append(.lesson(LessonFeature.State(lesson: lesson)))
            return .none

        case .progress:
            state.selectedTab = .profile
            return .none
        }
    }

    /// The first lesson the learner can actually open: in unit then lesson order,
    /// the first that is neither locked nor already completed.
    ///
    /// Internal rather than private so the deep link behaviour can be tested
    /// directly: the test bundle cannot use TCA's `TestStore` on this toolchain
    /// (see `project.yml`), so the rule is tested as a pure function.
    static func nextOpenableLesson(in units: [LearningUnit]) -> LessonSummary? {
        units
            .sorted { $0.orderIndex < $1.orderIndex }
            .flatMap { $0.lessons.sorted { $0.orderIndex < $1.orderIndex } }
            .first { !$0.isLocked && !$0.isCompleted }
    }
}
