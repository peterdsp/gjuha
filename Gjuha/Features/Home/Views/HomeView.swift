import SwiftUI
import ComposableArchitecture

struct HomeView: View {
    let store: StoreOf<HomeFeature>
    @State private var animateEntrance = false

    var body: some View {
        ZStack {
            GjuhaLiquidGlassBackground()

            ScrollView {
                VStack(spacing: 0) {
                    HomeHeaderView(streak: store.currentStreak, xp: store.totalXP)
                        .padding(.horizontal, 16)
                        .padding(.top, 12)

                    if store.isLoading {
                        ProgressView()
                            .padding(.top, 48)
                    } else {
                        LazyVStack(spacing: 24) {
                            ForEach(Array(store.units.enumerated()), id: \.element.id) { index, unit in
                                LearningUnitRowView(
                                    unit: unit,
                                    isVisible: animateEntrance,
                                    entranceDelay: Double(index) * 0.08
                                ) { lesson in
                                    store.send(.lessonTapped(lesson))
                                }
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.top, 20)
                        .padding(.bottom, 28)
                    }
                }
            }
        }
        .navigationBarHidden(true)
        .onAppear {
            if !animateEntrance {
                animateEntrance = true
            }
            store.send(.onAppear)
        }
    }
}

private struct HomeHeaderView: View {
    let streak: Int
    let xp: Int
    @State private var pulse = false

    var body: some View {
        HStack {
            HStack(spacing: 4) {
                Image(systemName: "flame.fill")
                    .foregroundStyle(Color.gjuha.streak)
                    .scaleEffect(pulse ? 1.14 : 0.94)
                    .animation(.easeInOut(duration: 0.95).repeatForever(autoreverses: true), value: pulse)
                Text("\(streak)")
                    .font(.gjuha.labelBold)
                    .foregroundStyle(Color.gjuha.streak)
            }
            Spacer()
            HStack(spacing: 4) {
                Image(systemName: "star.fill")
                    .foregroundStyle(Color.gjuha.xp)
                    .scaleEffect(pulse ? 0.94 : 1.14)
                    .animation(.easeInOut(duration: 1.25).repeatForever(autoreverses: true), value: pulse)
                Text("\(xp)")
                    .font(.gjuha.labelBold)
                    .foregroundStyle(Color.gjuha.xp)
            }
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 16)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(alignment: .bottom) {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color.white.opacity(0.28), lineWidth: 0.8)
        }
        .shadow(color: .black.opacity(0.12), radius: 14, y: 8)
        .onAppear {
            pulse = true
        }
    }
}

private struct LearningUnitRowView: View {
    let unit: LearningUnit
    let isVisible: Bool
    let entranceDelay: Double
    let onLessonTap: (LessonSummary) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(unit.title)
                .font(.gjuha.headingMedium)
                .foregroundStyle(Color.gjuha.textPrimary)

            Text(unit.description)
                .font(.gjuha.bodyRegular)
                .foregroundStyle(Color.gjuha.textSecondary)

            ForEach(unit.lessons) { lesson in
                Button(action: { onLessonTap(lesson) }) {
                    LessonNodeView(lesson: lesson)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(16)
        .gjuhaLiquidGlassCard(cornerRadius: 20, tintOpacity: 0.06)
        .opacity(isVisible ? 1 : 0)
        .offset(y: isVisible ? 0 : 16)
        .scaleEffect(isVisible ? 1.0 : 0.98)
        .animation(
            .spring(response: 0.52, dampingFraction: 0.86, blendDuration: 0.2)
            .delay(entranceDelay),
            value: isVisible
        )
    }
}

private struct LessonNodeView: View {
    let lesson: LessonSummary
    @State private var completedPulse = false

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(lesson.isCompleted ? Color.gjuha.accent : Color.gjuha.surfaceSecondary)
                    .frame(width: 48, height: 48)
                Image(systemName: lesson.iconName)
                    .foregroundStyle(lesson.isCompleted ? .white : Color.gjuha.textSecondary)
            }
            .scaleEffect(lesson.isCompleted && completedPulse ? 1.08 : 1.0)
            .animation(
                lesson.isCompleted
                ? .easeInOut(duration: 0.95).repeatForever(autoreverses: true)
                : .default,
                value: completedPulse
            )

            VStack(alignment: .leading, spacing: 2) {
                Text(lesson.title)
                    .font(.gjuha.labelBold)
                    .foregroundStyle(Color.gjuha.textPrimary)
                Text(lesson.subtitle)
                    .font(.gjuha.caption)
                    .foregroundStyle(Color.gjuha.textSecondary)
            }

            Spacer()

            if lesson.isCompleted {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(Color.gjuha.success)
            } else {
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Color.gjuha.textTertiary)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(.white.opacity(0.12))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .contentShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .onAppear {
            if lesson.isCompleted {
                completedPulse = true
            }
        }
    }
}
