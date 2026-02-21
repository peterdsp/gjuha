import SwiftUI
import ComposableArchitecture

struct ProfileView: View {
    let store: StoreOf<ProfileFeature>

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                StatsGridView(stats: store.stats)

                GoalPickerView(selected: store.selectedGoal) { goal in
                    store.send(.goalChanged(goal))
                }
            }
            .padding(16)
        }
        .background(Color.gjuha.background)
        .navigationTitle("Profile")
        .navigationBarTitleDisplayMode(.large)
        .onAppear { store.send(.onAppear) }
    }
}

private struct StatsGridView: View {
    let stats: UserStats

    var body: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
            StatCardView(label: "Day Streak", value: "\(stats.currentStreak)", icon: "flame.fill", color: Color.gjuha.streak)
            StatCardView(label: "Total XP", value: "\(stats.totalXP)", icon: "star.fill", color: Color.gjuha.xp)
            StatCardView(label: "Words Learned", value: "\(stats.wordsLearned)", icon: "book.fill", color: Color.gjuha.accent)
            StatCardView(label: "Lessons Done", value: "\(stats.lessonsCompleted)", icon: "checkmark.seal.fill", color: Color.gjuha.success)
        }
    }
}

private struct StatCardView: View {
    let label: String
    let value: String
    let icon: String
    let color: Color

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(color)
            Text(value)
                .font(.gjuha.headingLarge)
                .foregroundStyle(Color.gjuha.textPrimary)
            Text(label)
                .font(.gjuha.caption)
                .foregroundStyle(Color.gjuha.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(16)
        .background(Color.gjuha.surface)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

private struct GoalPickerView: View {
    let selected: LearningGoal
    let onChange: (LearningGoal) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Daily Goal")
                .font(.gjuha.headingMedium)
                .foregroundStyle(Color.gjuha.textPrimary)

            ForEach(LearningGoal.allCases, id: \.self) { goal in
                Button(action: { onChange(goal) }) {
                    HStack {
                        Text(goal.displayName)
                            .font(.gjuha.labelBold)
                            .foregroundStyle(Color.gjuha.textPrimary)
                        Text("— \(goal.minutesPerDay) min/day")
                            .font(.gjuha.bodyRegular)
                            .foregroundStyle(Color.gjuha.textSecondary)
                        Spacer()
                        if selected == goal {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(Color.gjuha.accent)
                        }
                    }
                    .padding(14)
                    .background(selected == goal ? Color.gjuha.accentSubtle : Color.gjuha.surface)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                }
            }
        }
        .padding(16)
        .background(Color.gjuha.surface)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}
