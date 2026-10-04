import SwiftUI
import ComposableArchitecture

struct ProfileView: View {
    let store: StoreOf<ProfileFeature>

    var body: some View {
        ZStack {
            GjuhaLiquidGlassBackground()

            ScrollView {
                VStack(spacing: 24) {
                    StatsGridView(stats: store.stats)

                    GoalPickerView(selected: store.selectedGoal) { goal in
                        store.send(.goalChanged(goal))
                    }

                    ReminderSettingsView(store: store)

                    DataControlsView(store: store)
                }
                .padding(16)
                .gjuhaReadableWidth()
            }
        }
        .navigationTitle("Profile")
        .navigationBarTitleDisplayMode(.large)
        .onAppear { store.send(.onAppear) }
        .alert(
            "Notifications are off",
            isPresented: Binding(
                get: { store.reminderPermissionDenied },
                set: { if !$0 { store.send(.reminderPermissionAlertDismissed) } }
            )
        ) {
            Button("OK", role: .cancel) { store.send(.reminderPermissionAlertDismissed) }
        } message: {
            Text("To get a daily reminder, allow notifications for Gjuha in the Settings app.")
        }
        .alert(
            "Reset learning data?",
            isPresented: Binding(
                get: { store.showResetConfirmation },
                set: { if !$0 { store.send(.resetConfirmationDismissed) } }
            )
        ) {
            Button("Cancel", role: .cancel) { store.send(.resetConfirmationDismissed) }
            Button("Reset", role: .destructive) { store.send(.resetConfirmed) }
        } message: {
            Text("This clears your XP, streak, completed lessons, and review schedule on this device. Your daily goal is kept. This cannot be undone.")
        }
    }
}

private struct DataControlsView: View {
    let store: StoreOf<ProfileFeature>

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Your Data")
                .font(.gjuha.headingMedium)
                .foregroundStyle(Color.gjuha.textPrimary)

            Text("Everything you learn is stored only on this device. Nothing is sent anywhere.")
                .font(.gjuha.caption)
                .foregroundStyle(Color.gjuha.textSecondary)
                .fixedSize(horizontal: false, vertical: true)

            Button(role: .destructive, action: { store.send(.resetDataTapped) }) {
                HStack(spacing: 8) {
                    Image(systemName: "trash")
                    Text("Reset learning data")
                        .font(.gjuha.labelBold)
                    Spacer()
                }
                .foregroundStyle(Color.gjuha.error)
                .padding(14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.gjuha.error.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Reset learning data")
            .accessibilityHint("Clears your progress and review schedule on this device")
        }
        .padding(16)
        .gjuhaLiquidGlassCard(cornerRadius: 18, tintOpacity: 0.07)
    }
}

private struct ReminderSettingsView: View {
    let store: StoreOf<ProfileFeature>

    /// Bridges the stored hour and minute to a Date for the system time picker, and
    /// writes the chosen hour and minute back. The date part is irrelevant; only the
    /// time of day is used.
    private var timeBinding: Binding<Date> {
        Binding(
            get: {
                Calendar.current.date(
                    bySettingHour: store.reminder.hour,
                    minute: store.reminder.minute,
                    second: 0,
                    of: Date()
                ) ?? Date()
            },
            set: { newDate in
                let comps = Calendar.current.dateComponents([.hour, .minute], from: newDate)
                store.send(.reminderTimeChanged(hour: comps.hour ?? 19, minute: comps.minute ?? 0))
            }
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Daily Reminder")
                .font(.gjuha.headingMedium)
                .foregroundStyle(Color.gjuha.textPrimary)

            Toggle(isOn: Binding(
                get: { store.reminder.isEnabled },
                set: { store.send(.reminderToggled($0)) }
            )) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Remind me to practice")
                        .font(.gjuha.labelBold)
                        .foregroundStyle(Color.gjuha.textPrimary)
                    Text("A gentle nudge once a day. Off by default.")
                        .font(.gjuha.caption)
                        .foregroundStyle(Color.gjuha.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .tint(Color.gjuha.accent)

            if store.reminder.isEnabled {
                Divider().overlay(Color.white.opacity(0.15))
                DatePicker(
                    "Reminder time",
                    selection: timeBinding,
                    displayedComponents: .hourAndMinute
                )
                .font(.gjuha.labelBold)
                .foregroundStyle(Color.gjuha.textPrimary)
                .tint(Color.gjuha.accent)
            }
        }
        .padding(16)
        .gjuhaLiquidGlassCard(cornerRadius: 18, tintOpacity: 0.07)
        .accessibilityElement(children: .contain)
    }
}

private struct StatsGridView: View {
    let stats: UserStats

    var body: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
            StatCardView(label: "Day Streak", value: "\(stats.currentStreak)", icon: "flame.fill", color: Color.gjuha.streak)
            StatCardView(label: "Total XP", value: "\(stats.totalXP)", icon: "star.fill", color: Color.gjuha.xp)
            StatCardView(label: "Words seen", value: "\(stats.wordsSeen)", icon: "book.fill", color: Color.gjuha.accent)
            StatCardView(label: "Lessons Done", value: "\(stats.lessonsCompleted)", icon: "checkmark.seal.fill", color: Color.gjuha.success)
            // Honest retention ladder: seen (exposure) < practiced (in the review
            // schedule) < mastered (survived to the long term interval).
            StatCardView(label: "In review", value: "\(stats.wordsPracticed)", icon: "arrow.triangle.2.circlepath", color: Color.gjuha.accent)
            StatCardView(label: "Mastered", value: "\(stats.wordsMastered)", icon: "trophy.fill", color: Color.gjuha.xp)
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
        .gjuhaLiquidGlassCard(cornerRadius: 14, tintOpacity: 0.06)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(label)
        .accessibilityValue(value)
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
                        Text("- \(goal.minutesPerDay) min/day")
                            .font(.gjuha.bodyRegular)
                            .foregroundStyle(Color.gjuha.textSecondary)
                        Spacer()
                        if selected == goal {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(Color.gjuha.accent)
                        }
                    }
                    .padding(14)
                    .background(selected == goal ? Color.gjuha.accentSubtle.opacity(0.92) : Color.white.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(selected == goal ? Color.gjuha.accent.opacity(0.65) : Color.white.opacity(0.2), lineWidth: 0.8)
                    )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(16)
        .gjuhaLiquidGlassCard(cornerRadius: 18, tintOpacity: 0.07)
    }
}
