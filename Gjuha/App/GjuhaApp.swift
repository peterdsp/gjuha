import SwiftUI
import SwiftData
import ComposableArchitecture

@main
struct GjuhaApp: App {
    static let store = Store(initialState: AppFeature.State()) {
        AppFeature()
    }

    var body: some Scene {
        WindowGroup {
            AppView(store: GjuhaApp.store)
                .modelContainer(GjuhaSchema.container)
        }
    }
}
