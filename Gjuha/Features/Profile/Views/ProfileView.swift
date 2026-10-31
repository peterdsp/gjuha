import SwiftUI
import ComposableArchitecture

struct ProfileView: View {
    let store: StoreOf<ProfileFeature>

    /// Profile is the app's one genuinely wide screen: six stat tiles, a twelve
    /// badge grid, a goal picker and two settings blocks, all independent of each
    /// other. On a compact width that is a long scroll, and on a regular width
    /// the previous single 620pt column left most of an iPad empty.
    ///
    /// Size class, not device or orientation: Apple's Layout guidance is to
    /// "determine layout based on size classes, not device type or orientation",
    /// and the two that matter here are the same app at two widths. It is also
    /// what gives iPhone Duo its layout for free, where the outer display is
    /// compact and the inner one regular.
    ///
    /// Two columns rather than three: on iPhone Duo's inner display the fold
    /// divides the screen, and the iPhone Duo guidance asks for an even number of
    /// columns "so content divides cleanly".
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    private var isRegularWidth: Bool { horizontalSizeClass == .regular }

    var body: some View {
        ZStack {
            GjuhaAmbientBackground()

            ScrollView {
                Group {
                    if isRegularWidth {
                        HStack(alignment: .top, spacing: .gjuha.loose) {
                            VStack(spacing: .gjuha.loose) {
                                progressSection
                            }
                            VStack(spacing: .gjuha.loose) {
                                settingsSection
                            }
                        }
                    } else {
                        VStack(spacing: .gjuha.loose) {
                            progressSection
                            settingsSection
                        }
                    }
                }
                .padding(.gjuha.regular)
                // The 620pt cap exists to keep prose at a readable measure. Two
                // columns of cards and grids are not prose, so the cap doubles
                // rather than squeezing both columns into one column's width.
                .gjuhaReadableWidth(isRegularWidth ? 1_040 : 620)
            }
        }
        .gjuhaScreenTitle("Profile")
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

extension ProfileView {
    /// What the learner has done. Ordered so today's goal leads, then the honest
    /// progress figures, then the milestones built from them.
    @ViewBuilder
    fileprivate var progressSection: some View {
        DailyGoalCard(stats: store.stats)

        StatsGridView(stats: store.stats)

        AchievementsSection(
            stats: store.stats,
            unlockDates: store.achievementUnlockDates,
            nextUp: store.nextAchievement
        )
    }

    /// What the learner can change.
    @ViewBuilder
    fileprivate var settingsSection: some View {
        GoalPickerView(selected: store.selectedGoal) { goal in
            store.send(.goalChanged(goal))
        }

        ReminderSettingsView(store: store)

        DataControlsView(store: store)
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
                .foregroundStyle(Color.gjuha.errorStrong)
                .padding(14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.gjuha.error.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .buttonStyle(.gjuhaCard)
            .accessibilityLabel("Reset learning data")
            .accessibilityHint("Clears your progress and review schedule on this device")
        }
        .padding(16)
        .gjuhaCardSurface(cornerRadius: 18, prominence: .standard)
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
            .tint(Color.gjuha.accentStrong)

            if store.reminder.isEnabled {
                Divider().overlay(Color.gjuha.hairline)
                DatePicker(
                    "Reminder time",
                    selection: timeBinding,
                    displayedComponents: .hourAndMinute
                )
                .font(.gjuha.labelBold)
                .foregroundStyle(Color.gjuha.textPrimary)
                .tint(Color.gjuha.accentStrong)
            }
        }
        .padding(16)
        .gjuhaCardSurface(cornerRadius: 18, prominence: .standard)
        .accessibilityElement(children: .contain)
    }
}

private struct StatsGridView: View {
    let stats: UserStats

    var body: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
            StatCardView(label: "Day streak", value: "\(stats.currentStreak)", icon: "flame.fill", color: Color.gjuha.streakStrong)
            StatCardView(label: "Total XP", value: "\(stats.totalXP)", icon: "star.fill", color: Color.gjuha.xpStrong)
            StatCardView(label: "Words seen", value: "\(stats.wordsSeen)", icon: "book.fill", color: Color.gjuha.accentStrong)
            StatCardView(label: "Lessons Done", value: "\(stats.lessonsCompleted)", icon: "checkmark.seal.fill", color: Color.gjuha.successStrong)
            // Honest retention ladder: seen (exposure) < practiced (in the review
            // schedule) < mastered (survived to the long term interval).
            StatCardView(label: "In review", value: "\(stats.wordsPracticed)", icon: "arrow.triangle.2.circlepath", color: Color.gjuha.accentStrong)
            StatCardView(label: "Mastered", value: "\(stats.wordsMastered)", icon: "trophy.fill", color: Color.gjuha.xpStrong)
        }
    }
}

private struct StatCardView: View {
    /// Localized: see the note in AppView.TabItem about `Text(someString)`.
    let label: LocalizedStringKey
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
        .gjuhaCardSurface(cornerRadius: 14, prominence: .nested)
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
                        VStack(alignment: .leading, spacing: 2) {
                            Text(goal.displayName)
                                .font(.gjuha.labelBold)
                                .foregroundStyle(Color.gjuha.textPrimary)
                            // Both figures, because the ring on Home measures XP
                            // while the goal is chosen in minutes. Showing only
                            // minutes left the learner no way to tell what the
                            // ring was counting toward.
                            Text("\(goal.minutesPerDay) min/day · \(goal.dailyXPGoal) XP")
                                .font(.gjuha.caption)
                                .foregroundStyle(Color.gjuha.textSecondary)
                        }
                        Spacer()
                        if selected == goal {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(Color.gjuha.accentStrong)
                        }
                    }
                    .padding(14)
                    .background(selected == goal ? Color.gjuha.accentSubtle.opacity(0.92) : Color.gjuha.controlFill)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(selected == goal ? Color.gjuha.accentStrong.opacity(0.65) : Color.gjuha.hairline, lineWidth: 0.8)
                    )
                }
                .buttonStyle(.gjuhaCard)
            }
        }
        .padding(16)
        .gjuhaCardSurface(cornerRadius: 18, prominence: .standard)
    }
}

// MARK: - Daily Goal

/// Today's progress against the chosen goal, in full rather than as the compact
/// ring on Home.
private struct DailyGoalCard: View {
    let stats: UserStats

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var shown: Double = 0

    var body: some View {
        VStack(alignment: .leading, spacing: .gjuha.snug) {
            HStack(spacing: .gjuha.tight) {
                Image(systemName: stats.hasMetDailyGoal ? "checkmark.circle.fill" : "target")
                    .font(.gjuha.symbol(20, .semibold))
                    .foregroundStyle(stats.hasMetDailyGoal ? Color.gjuha.successStrong : Color.gjuha.accentStrong)

                Text("Today")
                    .font(.gjuha.headingMedium)
                    .foregroundStyle(Color.gjuha.textPrimary)

                Spacer(minLength: 0)

                Text("\(stats.xpToday)/\(stats.dailyGoalXP) XP")
                    .font(.gjuha.captionBold)
                    .foregroundStyle(Color.gjuha.textSecondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule(style: .continuous)
                        .fill(Color.gjuha.track)
                    Capsule(style: .continuous)
                        .fill(
                            stats.hasMetDailyGoal
                            ? LinearGradient(
                                colors: [Color.gjuha.success, Color.gjuha.success],
                                startPoint: .leading, endPoint: .trailing
                              )
                            : LinearGradient(
                                colors: [Color.gjuha.accent, Color.gjuha.streak],
                                startPoint: .leading, endPoint: .trailing
                              )
                        )
                        .frame(width: geo.size.width * shown)
                }
            }
            .frame(height: 10)

            Text(
                stats.hasMetDailyGoal
                ? "Goal met. Anything more today is a bonus."
                : "Finish a lesson or a review to get there."
            )
            .font(.gjuha.caption)
            .foregroundStyle(Color.gjuha.textSecondary)
            .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.gjuha.regular)
        .gjuhaCardSurface(cornerRadius: GjuhaSpacing.Radius.large, prominence: .standard)
        .onAppear { set(stats.dailyGoalProgress) }
        .onChange(of: stats.dailyGoalProgress) { _, new in set(new) }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Today's goal")
        .accessibilityValue(
            stats.hasMetDailyGoal
            ? Text("Goal met. \(stats.xpToday) of \(stats.dailyGoalXP) XP")
            : Text("\(stats.xpToday) of \(stats.dailyGoalXP) XP")
        )
    }

    private func set(_ progress: Double) {
        guard !reduceMotion else {
            shown = progress
            return
        }
        withAnimation(.spring(response: 0.6, dampingFraction: 0.85)) { shown = progress }
    }
}

// MARK: - Achievements

private struct AchievementsSection: View {
    let stats: UserStats
    let unlockDates: [String: Date]
    let nextUp: Achievement?

    private var unlockedCount: Int { unlockDates.count }

    var body: some View {
        VStack(alignment: .leading, spacing: .gjuha.snug) {
            HStack {
                Text("Achievements")
                    .font(.gjuha.headingMedium)
                    .foregroundStyle(Color.gjuha.textPrimary)
                Spacer(minLength: 0)
                Text("\(unlockedCount)/\(AchievementCatalog.all.count)")
                    .font(.gjuha.captionBold)
                    .foregroundStyle(Color.gjuha.textSecondary)
            }

            if let nextUp, unlockedCount < AchievementCatalog.all.count {
                NextAchievementRow(achievement: nextUp, stats: stats)
            }

            LazyVGrid(
                columns: [GridItem(.adaptive(minimum: 84), spacing: .gjuha.snug)],
                spacing: .gjuha.snug
            ) {
                ForEach(AchievementCatalog.all) { achievement in
                    AchievementBadge(
                        achievement: achievement,
                        stats: stats,
                        unlockedOn: unlockDates[achievement.id]
                    )
                }
            }
        }
        .padding(.gjuha.regular)
        .gjuhaCardSurface(cornerRadius: GjuhaSpacing.Radius.large, prominence: .standard)
    }
}

/// The milestone within closest reach, with its real remaining distance.
private struct NextAchievementRow: View {
    let achievement: Achievement
    let stats: UserStats

    var body: some View {
        HStack(spacing: .gjuha.snug) {
            Image(systemName: achievement.symbolName)
                .font(.gjuha.symbol(16, .semibold))
                .foregroundStyle(Color.gjuha.accentStrong)
                .frame(width: 32, height: 32)
                .background(Color.gjuha.chipFill)
                .clipShape(Circle())

            VStack(alignment: .leading, spacing: 3) {
                Text(achievement.title)
                    .font(.gjuha.labelBold)
                    .foregroundStyle(Color.gjuha.textPrimary)

                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule().fill(Color.gjuha.track)
                        Capsule()
                            .fill(Color.gjuha.accent)
                            .frame(width: geo.size.width * achievement.progress(in: stats))
                    }
                }
                .frame(height: 5)
            }

            Text("\(achievement.progressValue(in: stats))/\(achievement.threshold)")
                .font(.gjuha.caption)
                .foregroundStyle(Color.gjuha.textSecondary)
                .monospacedDigit()
        }
        .padding(.vertical, .gjuha.tight)
        .padding(.horizontal, .gjuha.snug)
        .background(Color.gjuha.controlFill)
        .clipShape(RoundedRectangle(cornerRadius: GjuhaSpacing.Radius.small, style: .continuous))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("Next achievement: \(String(localized: achievement.title))"))
        .accessibilityValue(
            Text("\(achievement.progressValue(in: stats)) of \(achievement.threshold)")
        )
    }
}

private struct AchievementBadge: View {
    let achievement: Achievement
    let stats: UserStats
    let unlockedOn: Date?

    private var isUnlocked: Bool { unlockedOn != nil }

    var body: some View {
        VStack(spacing: .gjuha.tight) {
            ZStack {
                Circle()
                    .fill(isUnlocked ? Color.gjuha.xp : Color.gjuha.chipFill)
                    .frame(width: 52, height: 52)

                if !isUnlocked {
                    Circle()
                        .stroke(Color.gjuha.hairline, lineWidth: 1)
                        .frame(width: 52, height: 52)
                }

                Image(systemName: isUnlocked ? achievement.symbolName : "lock.fill")
                    .font(.gjuha.symbol(isUnlocked ? 22 : 17, .semibold))
                    .foregroundStyle(isUnlocked ? Color.gjuha.onWarning : Color.gjuha.textTertiary)
            }

            Text(achievement.title)
                .font(.gjuha.caption)
                .foregroundStyle(isUnlocked ? Color.gjuha.textPrimary : Color.gjuha.textTertiary)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(achievement.title)
        // Locked badges state the requirement and the distance, so the grid is
        // navigable rather than a wall of padlocks.
        .accessibilityValue(
            isUnlocked
            ? Text("Unlocked")
            : Text("Locked. \(String(localized: achievement.detail)) \(achievement.progressValue(in: stats)) of \(achievement.threshold)")
        )
    }
}
