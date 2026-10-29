import SwiftUI

// MARK: - Tab-root marker

private struct GjuhaIsTabRootKey: EnvironmentKey {
    static let defaultValue = false
}

extension EnvironmentValues {
    /// Whether this screen is being shown as the root of a tab, rather than
    /// pushed onto the navigation stack.
    ///
    /// It matters because the two contexts want opposite navigation chrome, and
    /// a real `TabView` keeps every tab alive at once.
    ///
    /// Before the app used a `TabView`, a `switch` with `.id(selectedTab)` meant
    /// exactly one screen existed, so each could set its own navigation
    /// preferences safely. Now all four are alive inside the one
    /// `NavigationStack`, so Home's `navigationBarHidden(true)` and the other
    /// three screens' `navigationTitle` all applied to the same bar at once.
    /// Home won, and the Vocabulary, Grammar and Profile titles silently
    /// stopped rendering.
    ///
    /// The textbook fix is a `NavigationStack` inside each `Tab`. That is not
    /// right here: `AppFeature` drives navigation from a single
    /// `StackState<Path.State>` that deep links, the lesson flow and the resume
    /// path all append to, and four stacks sharing one path would show the same
    /// pushed screen in every tab. Splitting it into four paths is a real
    /// refactor of tested navigation behaviour, so the chrome is resolved
    /// explicitly instead.
    var gjuhaIsTabRoot: Bool {
        get { self[GjuhaIsTabRootKey.self] }
        set { self[GjuhaIsTabRootKey.self] = newValue }
    }
}

// MARK: - Screen title

private struct GjuhaScreenTitleModifier: ViewModifier {
    let title: LocalizedStringKey

    @Environment(\.gjuhaIsTabRoot) private var isTabRoot

    func body(content: Content) -> some View {
        if isTabRoot {
            // The tab root draws its own header card, and the container owns the
            // navigation bar. Setting a title here would fight the other tabs
            // for the one bar they share.
            content
        } else {
            content
                .navigationTitle(title)
                .navigationBarTitleDisplayMode(.large)
        }
    }
}

extension View {
    /// Titles a screen when it is pushed, and stays out of the way when it is a
    /// tab root. Use instead of `navigationTitle` on any screen that is both.
    func gjuhaScreenTitle(_ title: LocalizedStringKey) -> some View {
        modifier(GjuhaScreenTitleModifier(title: title))
    }
}
