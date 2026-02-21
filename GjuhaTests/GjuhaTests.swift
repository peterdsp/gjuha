import Testing
import ComposableArchitecture
@testable import Gjuha

struct GjuhaTests {
    @Test
    func appReducerInitialState() async {
        let store = TestStore(initialState: AppFeature.State()) {
            AppFeature()
        }
        // Initial state: onboarding not completed
        #expect(store.state.hasCompletedOnboarding == false)
    }
}
