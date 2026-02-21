import SwiftUI
import ComposableArchitecture

struct AppView: View {
    let store: StoreOf<AppFeature>

    var body: some View {
        if store.hasCompletedOnboarding {
            NavigationStackStore(store.scope(state: \.path, action: \.path)) {
                HomeView(store: store.scope(state: \.home, action: \.home))
            } destination: { store in
                switch store.case {
                case .lesson(let store):
                    LessonView(store: store)
                case .vocabulary(let store):
                    VocabularyView(store: store)
                case .grammar(let store):
                    GrammarView(store: store)
                case .profile(let store):
                    ProfileView(store: store)
                }
            }
        } else {
            OnboardingView(
                store: Store(initialState: OnboardingFeature.State()) {
                    OnboardingFeature()
                }
            )
        }
    }
}
