import SwiftUI
import ComposableArchitecture

struct AppView: View {
    /// `@Bindable` because the navigation stack binds to the scoped path store.
    @Bindable var store: StoreOf<AppFeature>
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var showSplash = true
    @State private var hasStartedLaunchSequence = false

    var body: some View {
        ZStack {
            mainFlow
                .opacity(showSplash ? 0.001 : 1.0)

            if showSplash {
                LaunchExperienceView()
                    .transition(
                        .asymmetric(
                            insertion: .opacity,
                            removal: .opacity.combined(with: .scale(scale: 1.03))
                        )
                    )
                    .zIndex(1)
            }
        }
        .animation(.spring(response: 0.52, dampingFraction: 0.86), value: store.hasCompletedOnboarding)
        .task {
            guard !hasStartedLaunchSequence else { return }
            hasStartedLaunchSequence = true

            if store.hasCompletedOnboarding {
                store.send(.bootstrapData)
            }

            await waitForFirstScreen()

            if reduceMotion {
                showSplash = false
            } else {
                withAnimation(.spring(response: 0.72, dampingFraction: 0.88, blendDuration: 0.2)) {
                    showSplash = false
                }
            }
        }
        .onOpenURL { url in
            // Widget tap targets open gjuha:// URLs. Unrecognised URLs are
            // ignored rather than guessed at. Siri and Shortcuts reach the same
            // action through GjuhaIntentRouter, so both paths are identical from
            // here on.
            guard let link = GjuhaDeepLink(url: url) else { return }
            store.send(.deepLinkReceived(link))
        }
    }

    /// Holds the splash until the first screen is actually usable.
    ///
    /// Three bounds, in order of who they protect:
    ///
    /// - `floor` stops a warm launch, where the curriculum is already cached and
    ///   readiness is true on the first poll, from flashing the splash for one
    ///   frame. Reduce Motion gets a much shorter floor, because the thing the
    ///   floor is protecting is an animation that Reduce Motion does not play.
    /// - the poll loop is what makes a fast launch fast: as soon as
    ///   `isReadyForFirstScreen` flips, the splash leaves.
    /// - `cap` means a content failure cannot trap the learner behind the
    ///   splash. If the curriculum never loads, the app proceeds and Home shows
    ///   its own empty state, which is information; a permanent splash is not.
    private func waitForFirstScreen() async {
        let clock = ContinuousClock()
        let start = clock.now
        let floor: Duration = reduceMotion ? .milliseconds(120) : .milliseconds(420)
        let cap: Duration = .seconds(2.5)

        while clock.now - start < cap {
            if store.isReadyForFirstScreen, clock.now - start >= floor { return }
            try? await clock.sleep(for: .milliseconds(40))
            if Task.isCancelled { return }
        }
    }

    @ViewBuilder
    private var mainFlow: some View {
        if store.hasCompletedOnboarding {
            NavigationStack(path: $store.scope(state: \.path, action: \.path)) {
                RootTabView(store: store)
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
                case .culture(let store):
                    CultureView(store: store)
                case .culturalUnit(let store):
                    CulturalUnitDetailView(store: store)
                case .dialectPack(let store):
                    DialectPackDetailView(store: store)
                }
            }
            .transition(.asymmetric(insertion: .opacity.combined(with: .move(edge: .trailing)), removal: .opacity))
        } else {
            OnboardingView(store: store.scope(state: \.onboarding, action: \.onboarding))
                .transition(.asymmetric(insertion: .opacity, removal: .opacity.combined(with: .scale(scale: 1.02))))
        }
    }
}

/// The four top-level destinations.
///
/// This replaced a hand-built floating capsule bar, for three reasons that were
/// all defects rather than matters of taste:
///
/// - **Switching tabs destroyed each tab's state.** The old bar drove a `switch`
///   inside a `ZStack` carrying `.id(store.selectedTab)`, so leaving a tab tore
///   its view down: the vocabulary search text and CEFR filter, and every scroll
///   position, were reset on the way back. Apple's tab-bar guidance is explicit
///   that a section keeps its own state independently of which tab is selected.
///   A real `TabView` holds each tab's content alive, so returning to Words
///   finds the same query and the same scroll offset.
/// - **The selected label failed contrast.** The capsule was a hardcoded black
///   gradient in both appearances, with the selected item tinted `accent`.
///   Accent-on-black measured 3.3:1 behind an 11pt semibold label, under the
///   4.5:1 floor, and Apple's colour guidance prefers a tinted *background* for
///   a selected control over coloured label text.
/// - **It reimplemented behaviour the system already has.** A native tab bar
///   brings Liquid Glass, the scroll-edge effect, the iPad sidebar adaptation
///   this universal app is listed for, the tab-bar minimise behaviour, and
///   VoiceOver's "tab 2 of 4" position reporting, none of which the custom bar
///   provided.
private struct RootTabView: View {
    let store: StoreOf<AppFeature>

    private var selectedTab: Binding<AppFeature.State.RootTab> {
        Binding(
            get: { store.selectedTab },
            set: { store.send(.tabSelected($0)) }
        )
    }

    var body: some View {
        TabView(selection: selectedTab) {
            Tab("Learn", systemImage: "bolt.fill", value: AppFeature.State.RootTab.home) {
                HomeView(store: store.scope(state: \.home, action: \.home))
            }

            Tab("Words", systemImage: "text.book.closed.fill", value: AppFeature.State.RootTab.vocabulary) {
                VocabularyView(store: store.scope(state: \.vocabulary, action: \.vocabulary))
            }

            Tab("Grammar", systemImage: "book.pages.fill", value: AppFeature.State.RootTab.grammar) {
                GrammarView(store: store.scope(state: \.grammar, action: \.grammar))
            }

            Tab("Profile", systemImage: "person.crop.circle.fill", value: AppFeature.State.RootTab.profile) {
                ProfileView(store: store.scope(state: \.profile, action: \.profile))
            }
        }
        // iPad is a listed device family for this app, and a four-destination
        // learning course reads better in a sidebar on a 13" screen than as a
        // centred bar with three quarters of the width empty. On iPhone this is
        // a no-op and the bar stays at the bottom.
        .tabViewStyle(.sidebarAdaptable)
        // Gives the lesson map the full screen while the learner scrolls it, and
        // brings the bar back the moment they scroll up.
        .tabBarMinimizeBehavior(.onScrollDown)
        .tint(Color.gjuha.accentStrong)
        // Every tab root draws its own header card, so none of them needs a
        // navigation title, and the container is the only place that can say so
        // once rather than four times. See `gjuhaIsTabRoot`: with a real
        // `TabView` all four tabs stay alive, so a per-screen
        // `navigationBarHidden` or `navigationTitle` fights the other three for
        // one bar. Home won that fight and the other three titles stopped
        // rendering, which is why the chrome is decided here.
        .environment(\.gjuhaIsTabRoot, true)
        .toolbar(.hidden, for: .navigationBar)
    }
}

/// The branded splash, shown over the first screen while it loads.
///
/// White is used literally throughout this view rather than through a token, and
/// that is correct here: everything below sits on an opaque accent-to-streak
/// gradient this view draws itself, not on an adaptive surface. The appearance
/// cannot change what is behind these shapes, so there is nothing for a token to
/// adapt to. Elsewhere in the app a literal white overlay was a bug, because the
/// surface underneath it is `#FFFFFF` in light appearance.
private struct LaunchExperienceView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var gradientMotion = false
    @State private var drift = false
    @State private var iconBreath = false
    @State private var iconFloat = false
    @State private var shimmer = false

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color.gjuha.accent,
                    Color.gjuha.streak.opacity(0.95),
                    Color.gjuha.accent.opacity(0.92)
                ],
                startPoint: gradientMotion ? .topLeading : .bottomTrailing,
                endPoint: gradientMotion ? .bottomTrailing : .topLeading
            )
            .ignoresSafeArea()
            .animation(
                reduceMotion
                ? .linear(duration: 0.01)
                : .easeInOut(duration: 2.4).repeatForever(autoreverses: true),
                value: gradientMotion
            )

            Circle()
                .fill(.white.opacity(0.16))
                .frame(width: 330, height: 330)
                .blur(radius: 12)
                .offset(x: drift ? -120 : 120, y: drift ? -180 : 180)
                .animation(
                    reduceMotion
                    ? .linear(duration: 0.01)
                    : .easeInOut(duration: 3.2).repeatForever(autoreverses: true),
                    value: drift
                )

            Circle()
                .fill(.black.opacity(0.08))
                .frame(width: 260, height: 260)
                .blur(radius: 16)
                .offset(x: drift ? 140 : -140, y: drift ? 220 : -220)
                .animation(
                    reduceMotion
                    ? .linear(duration: 0.01)
                    : .easeInOut(duration: 3.0).repeatForever(autoreverses: true),
                    value: drift
                )

            VStack(spacing: 20) {
                ZStack {
                    Circle()
                        .fill(.white.opacity(0.22))
                        .frame(width: 232, height: 232)
                        .blur(radius: 8)

                    Image("MascotIcon")
                        .resizable()
                        .interpolation(.high)
                        .antialiased(true)
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 192, height: 192)
                        .shadow(color: .black.opacity(0.24), radius: 20, y: 12)
                        .scaleEffect(iconBreath ? 1.04 : 0.92)
                        .offset(y: iconFloat ? -4 : 4)
                        .rotationEffect(.degrees(iconFloat ? -2.2 : 2.2))
                        .animation(
                            reduceMotion
                            ? .linear(duration: 0.01)
                            : .easeInOut(duration: 0.86).repeatForever(autoreverses: true),
                            value: iconBreath
                        )
                        .animation(
                            reduceMotion
                            ? .linear(duration: 0.01)
                            : .easeInOut(duration: 1.24).repeatForever(autoreverses: true),
                            value: iconFloat
                        )

                    SparkleGlyph(
                        size: 24,
                        opacity: shimmer ? 1.0 : 0.52,
                        scale: shimmer ? 1.18 : 0.82
                    )
                    .offset(x: 80, y: -88)
                    .animation(
                        reduceMotion
                        ? .linear(duration: 0.01)
                        : .easeInOut(duration: 1.08).repeatForever(autoreverses: true),
                        value: shimmer
                    )

                    SparkleGlyph(
                        size: 16,
                        opacity: shimmer ? 0.78 : 0.3,
                        scale: shimmer ? 1.02 : 0.66
                    )
                    .offset(x: -82, y: 70)
                    .animation(
                        reduceMotion
                        ? .linear(duration: 0.01)
                        : .easeInOut(duration: 0.92).repeatForever(autoreverses: true).delay(0.14),
                        value: shimmer
                    )
                }
                .frame(width: 250, height: 250)

                VStack(spacing: 6) {
                    // The launch wordmark. A display token, not the glyph
                    // helper: the helper exists so an icon tracks the text
                    // beside it, and using it for text hides what the type
                    // actually is.
                    Text("Gjuha")
                        .font(.gjuha.displayMedium)
                        .gjuhaDisplayTracking(-1.2)
                        .foregroundStyle(.white)

                    Text("Learn Albanian. Feel Albanian.")
                        .font(.gjuha.headingSmall)
                        .foregroundStyle(.white.opacity(0.94))
                }

                HStack(spacing: 8) {
                    ForEach(0..<3, id: \.self) { index in
                        Circle()
                            .fill(.white.opacity(shimmer ? 1.0 : 0.45))
                            .frame(width: 8, height: 8)
                            .scaleEffect(shimmer ? 1.2 : 0.85)
                            .animation(
                                reduceMotion
                                ? .linear(duration: 0.01)
                                : .easeInOut(duration: 0.8)
                                    .repeatForever(autoreverses: true)
                                    .delay(Double(index) * 0.14),
                                value: shimmer
                            )
                    }
                }
                .padding(.top, 6)
            }
            .padding(.horizontal, 24)
        }
        .onAppear {
            if reduceMotion {
                shimmer = true
                return
            }

            gradientMotion = true
            drift = true
            iconBreath = true
            iconFloat = true
            shimmer = true
        }
    }
}

private struct SparkleGlyph: View {
    let size: CGFloat
    let opacity: Double
    let scale: CGFloat

    var body: some View {
        Image(systemName: "sparkle")
            .font(.gjuha.symbol(size, .heavy))
            .foregroundStyle(Color.gjuha.warning)
            .shadow(color: .white.opacity(0.4), radius: 4)
            .opacity(opacity)
            .scaleEffect(scale)
    }
}
