import SwiftUI
import SwiftData
import ComposableArchitecture

@main
struct GjuhaApp: App {
    static let store = Store(initialState: AppFeature.State()) {
        AppFeature()
    }

    init() {
        #if DEBUG
        // Runs before the store is first touched, so a UI test that asked for a
        // clean slate gets one before `AppFeature.State` reads the onboarding
        // flag. No-op unless the launch argument is present, and absent entirely
        // from release builds.
        UITestSupport.resetStateIfRequested()
        #endif
    }

    var body: some Scene {
        WindowGroup {
            AppView(store: GjuhaApp.store)
                .modelContainer(GjuhaSchema.container)
        }
    }
}
