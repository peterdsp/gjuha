import Foundation

/// The single way anything outside the app asks the app to do something.
///
/// Siri, the Shortcuts app, the Action button, and a widget tap all end up here,
/// so there is exactly one code path from "outside" into TCA state instead of one
/// per entry point. Everything is funnelled as a `GjuhaDeepLink`, which keeps the
/// set of externally reachable actions small, reviewable, and the same in every
/// surface.
///
/// `@MainActor` because it touches the TCA store, which must only be used from the
/// main actor. App Intents' `perform()` is deliberately *not* main-actor isolated,
/// so intents hop here explicitly.
@MainActor
enum GjuhaIntentRouter {
    static func route(_ link: GjuhaDeepLink) {
        GjuhaApp.store.send(.deepLinkReceived(link))
    }
}
