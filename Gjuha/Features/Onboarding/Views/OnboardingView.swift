import SwiftUI
import ComposableArchitecture

struct OnboardingView: View {
    let store: StoreOf<OnboardingFeature>
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack {
            OnboardingBackdropView()

            switch store.step {
            case .welcome:
                WelcomeStepView { store.send(.nextStepTapped) }
                    .transition(
                        .asymmetric(
                            insertion: .move(edge: .trailing).combined(with: .opacity),
                            removal: .move(edge: .leading).combined(with: .opacity)
                        )
                    )
            case .reason:
                ReasonStepView(
                    selected: store.selectedReason,
                    onSelect: { store.send(.reasonSelected($0)) },
                    onNext: { store.send(.nextStepTapped) }
                )
                .transition(
                    .asymmetric(
                        insertion: .move(edge: .trailing).combined(with: .opacity),
                        removal: .move(edge: .leading).combined(with: .opacity)
                    )
                )
            case .goal:
                GoalStepView(
                    selected: store.selectedGoal,
                    onSelect: { store.send(.goalSelected($0)) },
                    onNext: { store.send(.nextStepTapped) }
                )
                .transition(
                    .asymmetric(
                        insertion: .move(edge: .trailing).combined(with: .opacity),
                        removal: .move(edge: .leading).combined(with: .opacity)
                    )
                )
            }
        }
        .animation(
            reduceMotion
            ? .linear(duration: 0.01)
            : .spring(response: 0.5, dampingFraction: 0.88, blendDuration: 0.2),
            value: store.step
        )
    }
}

private struct OnboardingBackdropView: View {
    @State private var drift = false

    var body: some View {
        ZStack {
            GjuhaLiquidGlassBackground()

            Circle()
                .fill(Color.gjuha.accent.opacity(0.08))
                .frame(width: 280, height: 280)
                .blur(radius: 4)
                .offset(x: drift ? -130 : 130, y: drift ? -260 : -220)
                .animation(.easeInOut(duration: 4.6).repeatForever(autoreverses: true), value: drift)

            Circle()
                .fill(Color.gjuha.streak.opacity(0.08))
                .frame(width: 220, height: 220)
                .blur(radius: 8)
                .offset(x: drift ? 150 : -120, y: drift ? 260 : 220)
                .animation(.easeInOut(duration: 4.1).repeatForever(autoreverses: true), value: drift)
        }
        .onAppear { drift = true }
    }
}

private struct WelcomeStepView: View {
    let onNext: () -> Void
    @State private var reveal = false
    @State private var pulse = false

    var body: some View {
        VStack(spacing: 32) {
            Spacer(minLength: 24)

            OnboardingProgressView(currentIndex: 0)

            ZStack {
                BrandBadgeView(pulse: pulse)
                    .scaleEffect(reveal ? 1.0 : 0.86)
                    .opacity(reveal ? 1 : 0)

                FloatingPhraseChip(text: "Përshëndetje", x: -114, y: -72, delay: 0.0)
                FloatingPhraseChip(text: "Faleminderit", x: 112, y: -44, delay: 0.2)
                FloatingPhraseChip(text: "Mirë se vini", x: 0, y: 98, delay: 0.4)
            }
            .frame(height: 210)

            VStack(spacing: 16) {
                Text("Mirë se vini")
                    .font(.gjuha.displayLarge)
                    .foregroundStyle(Color.gjuha.accent)
                    .opacity(reveal ? 1 : 0)
                    .offset(y: reveal ? 0 : 8)

                Text("Welcome to Gjuha")
                    .font(.gjuha.headingLarge)
                    .foregroundStyle(Color.gjuha.textPrimary)
                    .opacity(reveal ? 1 : 0)
                    .offset(y: reveal ? 0 : 8)

                Text("The most modern Albanian learning experience.")
                    .font(.gjuha.bodyRegular)
                    .foregroundStyle(Color.gjuha.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
                    .opacity(reveal ? 1 : 0)
                    .offset(y: reveal ? 0 : 8)
            }

            Spacer()

            Button(action: onNext) {
                Text("Get started")
                    .font(.gjuha.labelBold)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(
                        LinearGradient(
                            colors: [Color.gjuha.accent, Color.gjuha.accent.opacity(0.88)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .shadow(color: Color.gjuha.accent.opacity(0.3), radius: 12, y: 6)
            }
            .buttonStyle(PrimaryButtonStyle())
            .opacity(reveal ? 1 : 0)
            .offset(y: reveal ? 0 : 12)
            .padding(.horizontal, 24)
            .padding(.bottom, 44)
        }
        .onAppear {
            withAnimation(.spring(response: 0.65, dampingFraction: 0.84)) {
                reveal = true
            }
            pulse = true
        }
    }
}

private struct ReasonStepView: View {
    let selected: LearningReason
    let onSelect: (LearningReason) -> Void
    let onNext: () -> Void
    @State private var revealed = false

    var body: some View {
        VStack(spacing: 24) {
            OnboardingProgressView(currentIndex: 1)
                .padding(.top, 20)

            Text("Why are you learning Albanian?")
                .font(.gjuha.headingLarge)
                .foregroundStyle(Color.gjuha.textPrimary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)

            VStack(spacing: 8) {
                ForEach(Array(LearningReason.allCases.enumerated()), id: \.element) { index, reason in
                    Button(action: { onSelect(reason) }) {
                        HStack {
                            Text(reason.displayName)
                                .font(.gjuha.bodyRegular)
                                .foregroundStyle(Color.gjuha.textPrimary)
                            Spacer()
                            if selected == reason {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(Color.gjuha.accent)
                                    .scaleEffect(1.05)
                            }
                        }
                        .padding(16)
                        .background(selected == reason ? Color.gjuha.accentSubtle.opacity(0.92) : Color.white.opacity(0.12))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(selected == reason ? Color.gjuha.accent : Color.white.opacity(0.22), lineWidth: 1.2)
                        )
                        .shadow(
                            color: selected == reason ? Color.gjuha.accent.opacity(0.22) : .clear,
                            radius: 10,
                            y: 4
                        )
                        .scaleEffect(selected == reason ? 1.01 : 1.0)
                    }
                    .buttonStyle(.plain)
                    .opacity(revealed ? 1 : 0)
                    .offset(y: revealed ? 0 : 10)
                    .animation(
                        .spring(response: 0.48, dampingFraction: 0.86)
                        .delay(Double(index) * 0.06),
                        value: revealed
                    )
                    .padding(.horizontal, 24)
                }
            }
            .animation(.spring(response: 0.34, dampingFraction: 0.8), value: selected)

            Spacer()

            Button(action: onNext) {
                Text("Continue")
                    .font(.gjuha.labelBold)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(
                        LinearGradient(
                            colors: [Color.gjuha.accent, Color.gjuha.accent.opacity(0.88)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .shadow(color: Color.gjuha.accent.opacity(0.28), radius: 12, y: 6)
            }
            .buttonStyle(PrimaryButtonStyle())
            .padding(.horizontal, 24)
            .padding(.bottom, 44)
        }
        .onAppear {
            revealed = true
        }
    }
}

private struct GoalStepView: View {
    let selected: LearningGoal
    let onSelect: (LearningGoal) -> Void
    let onNext: () -> Void
    @State private var revealed = false

    var body: some View {
        VStack(spacing: 24) {
            OnboardingProgressView(currentIndex: 2)
                .padding(.top, 20)

            Text("Set your daily goal")
                .font(.gjuha.headingLarge)
                .foregroundStyle(Color.gjuha.textPrimary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)

            VStack(spacing: 8) {
                ForEach(Array(LearningGoal.allCases.enumerated()), id: \.element) { index, goal in
                    Button(action: { onSelect(goal) }) {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(goal.displayName)
                                    .font(.gjuha.labelBold)
                                    .foregroundStyle(Color.gjuha.textPrimary)
                                Text("\(goal.minutesPerDay) min / day")
                                    .font(.gjuha.caption)
                                    .foregroundStyle(Color.gjuha.textSecondary)
                            }
                            Spacer()
                            if selected == goal {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(Color.gjuha.accent)
                                    .scaleEffect(1.05)
                            }
                        }
                        .padding(16)
                        .background(selected == goal ? Color.gjuha.accentSubtle.opacity(0.92) : Color.white.opacity(0.12))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(selected == goal ? Color.gjuha.accent : Color.white.opacity(0.22), lineWidth: 1.2)
                        )
                        .shadow(
                            color: selected == goal ? Color.gjuha.accent.opacity(0.22) : .clear,
                            radius: 10,
                            y: 4
                        )
                        .scaleEffect(selected == goal ? 1.01 : 1.0)
                    }
                    .buttonStyle(.plain)
                    .opacity(revealed ? 1 : 0)
                    .offset(y: revealed ? 0 : 10)
                    .animation(
                        .spring(response: 0.48, dampingFraction: 0.86)
                        .delay(Double(index) * 0.06),
                        value: revealed
                    )
                    .padding(.horizontal, 24)
                }
            }
            .animation(.spring(response: 0.34, dampingFraction: 0.8), value: selected)

            Spacer()

            Button(action: onNext) {
                Text("Start learning")
                    .font(.gjuha.labelBold)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(
                        LinearGradient(
                            colors: [Color.gjuha.accent, Color.gjuha.accent.opacity(0.88)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .shadow(color: Color.gjuha.accent.opacity(0.28), radius: 12, y: 6)
            }
            .buttonStyle(PrimaryButtonStyle())
            .padding(.horizontal, 24)
            .padding(.bottom, 44)
        }
        .onAppear {
            revealed = true
        }
    }
}

private struct BrandBadgeView: View {
    let pulse: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var orbit = false

    var body: some View {
        ZStack {
            Circle()
                .fill(Color.gjuha.accent.opacity(0.14))
                .frame(width: 188, height: 188)
                .blur(radius: 6)

            Image("MascotIcon")
                .resizable()
                .interpolation(.high)
                .antialiased(true)
                .aspectRatio(contentMode: .fit)
                .frame(width: 168, height: 168)
                .shadow(color: .black.opacity(0.16), radius: 12, y: 8)

            OrbitSparkleView(size: 18, opacity: orbit ? 1.0 : 0.5, scale: orbit ? 1.12 : 0.72)
                .offset(x: 70, y: -70)
                .animation(
                    reduceMotion
                    ? .linear(duration: 0.01)
                    : .easeInOut(duration: 0.9).repeatForever(autoreverses: true),
                    value: orbit
                )

            OrbitSparkleView(size: 13, opacity: orbit ? 0.86 : 0.34, scale: orbit ? 0.96 : 0.62)
                .offset(x: -66, y: 62)
                .animation(
                    reduceMotion
                    ? .linear(duration: 0.01)
                    : .easeInOut(duration: 1.0).repeatForever(autoreverses: true).delay(0.12),
                    value: orbit
                )
        }
        .scaleEffect(reduceMotion ? 1.0 : (pulse ? 1.03 : 0.95))
        .offset(y: reduceMotion ? 0 : (orbit ? -2 : 2))
        .animation(
            reduceMotion
            ? .linear(duration: 0.01)
            : .easeInOut(duration: 1.1).repeatForever(autoreverses: true),
            value: pulse
        )
        .animation(
            reduceMotion
            ? .linear(duration: 0.01)
            : .easeInOut(duration: 1.26).repeatForever(autoreverses: true),
            value: orbit
        )
        .onAppear {
            if reduceMotion { return }
            orbit = true
        }
    }
}

private struct OrbitSparkleView: View {
    let size: CGFloat
    let opacity: Double
    let scale: CGFloat

    var body: some View {
        Image(systemName: "sparkle")
            .font(.system(size: size, weight: .heavy))
            .foregroundStyle(Color.gjuha.warning)
            .shadow(color: .white.opacity(0.38), radius: 4)
            .opacity(opacity)
            .scaleEffect(scale)
    }
}

private struct FloatingPhraseChip: View {
    let text: String
    let x: CGFloat
    let y: CGFloat
    let delay: Double
    @State private var animate = false

    var body: some View {
        Text(text)
            .font(.gjuha.captionBold)
            .foregroundStyle(Color.gjuha.textPrimary)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(.white.opacity(0.9))
            .clipShape(Capsule())
            .overlay(
                Capsule()
                    .stroke(Color.gjuha.border.opacity(0.8), lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.08), radius: 6, y: 3)
            .offset(x: x + (animate ? 6 : -6), y: y + (animate ? -8 : 8))
            .opacity(animate ? 1.0 : 0.74)
            .onAppear {
                withAnimation(
                    .easeInOut(duration: 2.2)
                    .repeatForever(autoreverses: true)
                    .delay(delay)
                ) {
                    animate = true
                }
            }
    }
}

private struct OnboardingProgressView: View {
    let currentIndex: Int

    var body: some View {
        HStack(spacing: 8) {
            ForEach(0..<3, id: \.self) { index in
                Capsule(style: .continuous)
                    .fill(index <= currentIndex ? Color.gjuha.accent : Color.gjuha.border.opacity(0.7))
                    .frame(width: index == currentIndex ? 22 : 14, height: 6)
                    .animation(.spring(response: 0.4, dampingFraction: 0.82), value: currentIndex)
            }
        }
    }
}

private struct PrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .opacity(configuration.isPressed ? 0.96 : 1.0)
            .animation(.spring(response: 0.24, dampingFraction: 0.76), value: configuration.isPressed)
    }
}
