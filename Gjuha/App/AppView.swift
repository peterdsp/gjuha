import SwiftUI
import ComposableArchitecture

struct AppView: View {
    let store: StoreOf<AppFeature>
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

            let launchDelay: UInt64 = reduceMotion ? 300_000_000 : 1_450_000_000
            try? await Task.sleep(nanoseconds: launchDelay)

            if reduceMotion {
                showSplash = false
            } else {
                withAnimation(.spring(response: 0.72, dampingFraction: 0.88, blendDuration: 0.2)) {
                    showSplash = false
                }
            }
        }
    }

    @ViewBuilder
    private var mainFlow: some View {
        if store.hasCompletedOnboarding {
            NavigationStackStore(store.scope(state: \.path, action: \.path)) {
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
                }
            }
            .transition(.asymmetric(insertion: .opacity.combined(with: .move(edge: .trailing)), removal: .opacity))
        } else {
            OnboardingView(store: store.scope(state: \.onboarding, action: \.onboarding))
                .transition(.asymmetric(insertion: .opacity, removal: .opacity.combined(with: .scale(scale: 1.02))))
        }
    }
}

private struct RootTabView: View {
    let store: StoreOf<AppFeature>

    private var selectedTab: Binding<AppFeature.State.RootTab> {
        Binding(
            get: { store.selectedTab },
            set: { store.send(.tabSelected($0)) }
        )
    }

    var body: some View {
        ZStack {
            switch store.selectedTab {
            case .home:
                HomeView(store: store.scope(state: \.home, action: \.home))
            case .vocabulary:
                VocabularyView(store: store.scope(state: \.vocabulary, action: \.vocabulary))
            case .grammar:
                GrammarView(store: store.scope(state: \.grammar, action: \.grammar))
            case .profile:
                ProfileView(store: store.scope(state: \.profile, action: \.profile))
            }
        }
        .id(store.selectedTab)
        .transition(.opacity)
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbarBackground(.ultraThinMaterial, for: .navigationBar)
        .safeAreaInset(edge: .bottom, spacing: 0) {
            FloatingPillTabBar(selectedTab: selectedTab)
                .padding(.horizontal, 20)
                .padding(.bottom, 8)
        }
        .animation(.spring(response: 0.4, dampingFraction: 0.86), value: store.selectedTab)
    }
}

private struct FloatingPillTabBar: View {
    @Binding var selectedTab: AppFeature.State.RootTab
    @Namespace private var activeTabAnimation

    private struct TabItem: Identifiable {
        let id: AppFeature.State.RootTab
        let title: String
        let icon: String
    }

    private let items: [TabItem] = [
        .init(id: .home, title: "Learn", icon: "bolt.fill"),
        .init(id: .vocabulary, title: "Words", icon: "text.book.closed.fill"),
        .init(id: .grammar, title: "Grammar", icon: "book.pages.fill"),
        .init(id: .profile, title: "Profile", icon: "person.crop.circle.fill")
    ]

    var body: some View {
        HStack(spacing: 2) {
            ForEach(items) { item in
                tabButton(tab: item.id, title: item.title, icon: item.icon)
            }
        }
        .frame(maxWidth: 560)
        .padding(.horizontal, 6)
        .padding(.vertical, 6)
        .background(
            ZStack {
                Capsule(style: .continuous)
                    .fill(.ultraThinMaterial)

                Capsule(style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.black.opacity(0.58),
                                Color.black.opacity(0.46)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            }
        )
        .overlay(
            Capsule(style: .continuous)
                .stroke(Color.white.opacity(0.28), lineWidth: 1.0)
        )
        .overlay(
            Capsule(style: .continuous)
                .stroke(Color.white.opacity(0.08), lineWidth: 3)
                .blur(radius: 1.2)
                .clipShape(Capsule(style: .continuous))
        )
        .shadow(color: .black.opacity(0.36), radius: 24, y: 12)
    }

    @ViewBuilder
    private func tabButton(
        tab: AppFeature.State.RootTab,
        title: String,
        icon: String
    ) -> some View {
        let isSelected = selectedTab == tab

        Button {
            withAnimation(.spring(response: 0.36, dampingFraction: 0.82)) {
                selectedTab = tab
            }
        } label: {
            VStack(spacing: 2) {
                Image(systemName: icon)
                    .font(.system(size: 17, weight: .semibold))
                    .symbolRenderingMode(.hierarchical)

                Text(title)
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
            }
            .foregroundStyle(isSelected ? Color.gjuha.accent : Color.white.opacity(0.88))
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity)
            .scaleEffect(isSelected ? 1.0 : 0.98)
            .background {
                if isSelected {
                    Capsule(style: .continuous)
                        .fill(Color.black.opacity(0.34))
                        .overlay(
                            Capsule(style: .continuous)
                                .fill(Color.white.opacity(0.08))
                        )
                        .overlay(
                            Capsule(style: .continuous)
                                .stroke(Color.white.opacity(0.22), lineWidth: 0.8)
                        )
                        .matchedGeometryEffect(id: "active-pill-tab", in: activeTabAnimation)
                }
            }
            .contentShape(Capsule(style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title)
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
    }
}

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
                    Text("Gjuha")
                        .font(.system(size: 44, weight: .black, design: .rounded))
                        .foregroundStyle(.white)

                    Text("Learn Albanian. Feel Albanian.")
                        .font(.system(size: 17, weight: .semibold, design: .rounded))
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
            .font(.system(size: size, weight: .heavy))
            .foregroundStyle(Color.gjuha.warning)
            .shadow(color: .white.opacity(0.4), radius: 4)
            .opacity(opacity)
            .scaleEffect(scale)
    }
}
