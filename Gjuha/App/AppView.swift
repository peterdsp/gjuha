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
                },
                onCompleted: { store.send(.onboardingCompleted) }
            )
        }
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
