import SwiftUI
import ComposableArchitecture

struct HomeView: View {
    let store: StoreOf<HomeFeature>

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                HomeHeaderView(streak: store.currentStreak, xp: store.totalXP)

                if store.isLoading {
                    ProgressView()
                        .padding(.top, 48)
                } else {
                    LazyVStack(spacing: 24) {
                        ForEach(store.units) { unit in
                            LearningUnitRowView(unit: unit) { lesson in
                                store.send(.lessonTapped(lesson))
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 24)
                }
            }
        }
        .background(Color.gjuha.background)
        .navigationBarHidden(true)
        .onAppear { store.send(.onAppear) }
    }
}

private struct HomeHeaderView: View {
    let streak: Int
    let xp: Int

    var body: some View {
        HStack {
            HStack(spacing: 4) {
                Image(systemName: "flame.fill")
                    .foregroundStyle(Color.gjuha.streak)
                Text("\(streak)")
                    .font(.gjuha.labelBold)
                    .foregroundStyle(Color.gjuha.streak)
            }
            Spacer()
            HStack(spacing: 4) {
                Image(systemName: "star.fill")
                    .foregroundStyle(Color.gjuha.xp)
                Text("\(xp)")
                    .font(.gjuha.labelBold)
                    .foregroundStyle(Color.gjuha.xp)
            }
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 16)
        .background(Color.gjuha.surface)
    }
}

private struct LearningUnitRowView: View {
    let unit: LearningUnit
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
                LessonNodeView(lesson: lesson)
                    .onTapGesture { onLessonTap(lesson) }
            }
        }
        .padding(16)
        .background(Color.gjuha.surface)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}

private struct LessonNodeView: View {
    let lesson: LessonSummary

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(lesson.isCompleted ? Color.gjuha.accent : Color.gjuha.surfaceSecondary)
                    .frame(width: 48, height: 48)
                Image(systemName: lesson.iconName)
                    .foregroundStyle(lesson.isCompleted ? .white : Color.gjuha.textSecondary)
            }

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
            }
        }
    }
}
