import SwiftUI
import ComposableArchitecture

struct OnboardingView: View {
    let store: StoreOf<OnboardingFeature>

    var body: some View {
        ZStack {
            Color.gjuha.background.ignoresSafeArea()

            switch store.step {
            case .welcome:
                WelcomeStepView { store.send(.nextStepTapped) }
                    .transition(.asymmetric(insertion: .move(edge: .trailing), removal: .move(edge: .leading)))
            case .reason:
                ReasonStepView(
                    selected: store.selectedReason,
                    onSelect: { store.send(.reasonSelected($0)) },
                    onNext: { store.send(.nextStepTapped) }
                )
                .transition(.asymmetric(insertion: .move(edge: .trailing), removal: .move(edge: .leading)))
            case .goal:
                GoalStepView(
                    selected: store.selectedGoal,
                    onSelect: { store.send(.goalSelected($0)) },
                    onNext: { store.send(.nextStepTapped) }
                )
                .transition(.asymmetric(insertion: .move(edge: .trailing), removal: .move(edge: .leading)))
            case .complete:
                EmptyView()
            }
        }
        .animation(.easeInOut(duration: 0.3), value: store.step)
    }
}

private struct WelcomeStepView: View {
    let onNext: () -> Void

    var body: some View {
        VStack(spacing: 32) {
            Spacer()

            VStack(spacing: 16) {
                Text("Mirë se vini")
                    .font(.gjuha.displayLarge)
                    .foregroundStyle(Color.gjuha.accent)

                Text("Welcome to Gjuha")
                    .font(.gjuha.headingLarge)
                    .foregroundStyle(Color.gjuha.textPrimary)

                Text("The most modern Albanian learning experience.")
                    .font(.gjuha.bodyRegular)
                    .foregroundStyle(Color.gjuha.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }

            Spacer()

            Button(action: onNext) {
                Text("Get started")
                    .font(.gjuha.labelBold)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(Color.gjuha.accent)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 48)
        }
    }
}

private struct ReasonStepView: View {
    let selected: LearningReason
    let onSelect: (LearningReason) -> Void
    let onNext: () -> Void

    var body: some View {
        VStack(spacing: 24) {
            Text("Why are you learning Albanian?")
                .font(.gjuha.headingLarge)
                .foregroundStyle(Color.gjuha.textPrimary)
                .multilineTextAlignment(.center)
                .padding(.top, 64)
                .padding(.horizontal, 24)

            VStack(spacing: 8) {
                ForEach(LearningReason.allCases, id: \.self) { reason in
                    Button(action: { onSelect(reason) }) {
                        HStack {
                            Text(reason.displayName)
                                .font(.gjuha.bodyRegular)
                                .foregroundStyle(Color.gjuha.textPrimary)
                            Spacer()
                            if selected == reason {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(Color.gjuha.accent)
                            }
                        }
                        .padding(16)
                        .background(selected == reason ? Color.gjuha.accentSubtle : Color.gjuha.surface)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(selected == reason ? Color.gjuha.accent : Color.clear, lineWidth: 2)
                        )
                    }
                    .padding(.horizontal, 24)
                }
            }

            Spacer()

            Button(action: onNext) {
                Text("Continue")
                    .font(.gjuha.labelBold)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(Color.gjuha.accent)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 48)
        }
    }
}

private struct GoalStepView: View {
    let selected: LearningGoal
    let onSelect: (LearningGoal) -> Void
    let onNext: () -> Void

    var body: some View {
        VStack(spacing: 24) {
            Text("Set your daily goal")
                .font(.gjuha.headingLarge)
                .foregroundStyle(Color.gjuha.textPrimary)
                .multilineTextAlignment(.center)
                .padding(.top, 64)
                .padding(.horizontal, 24)

            VStack(spacing: 8) {
                ForEach(LearningGoal.allCases, id: \.self) { goal in
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
                            }
                        }
                        .padding(16)
                        .background(selected == goal ? Color.gjuha.accentSubtle : Color.gjuha.surface)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(selected == goal ? Color.gjuha.accent : Color.clear, lineWidth: 2)
                        )
                    }
                    .padding(.horizontal, 24)
                }
            }

            Spacer()

            Button(action: onNext) {
                Text("Start learning")
                    .font(.gjuha.labelBold)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(Color.gjuha.accent)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 48)
        }
    }
}
