import SwiftUI
import ComposableArchitecture

struct HomeView: View {
    let store: StoreOf<HomeFeature>
    @State private var animateEntrance = false

    private var currentUnit: LearningUnit? {
        // Show the first unit that has at least one incomplete lesson
        store.units.first(where: { unit in
            !unit.isLocked && unit.lessons.contains(where: { !$0.isCompleted })
        }) ?? store.units.first(where: { !$0.isLocked })
    }

    private var completedUnitsCount: Int {
        store.units.filter { unit in
            !unit.lessons.isEmpty && unit.lessons.allSatisfy(\.isCompleted)
        }.count
    }

    /// At a regular width the context cards move into a leading rail and the
    /// lesson map keeps its own column.
    ///
    /// The map is a single vertical flow and reads correctly centred, so it is
    /// not split. What was wrong at a regular width is everything *around* it:
    /// the unit card, the review prompt and the culture card were stacked above
    /// and below the map, which on an iPad meant scrolling past a screen of
    /// context to reach the lessons and scrolling the whole map again to find the
    /// culture card. Apple's iPhone Duo guidance is to "show an additional level
    /// of hierarchy on the larger inner display if it makes sense for your
    /// content", and two columns is an even split, which is what the fold wants.
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    private var isRegularWidth: Bool { horizontalSizeClass == .regular }

    /// Two columns need the width *and* a map to put in the second one. The
    /// loading, no-content and all-finished states have nothing to pair with the
    /// rail, so they stay a single column at every width.
    private var usesTwoColumns: Bool {
        isRegularWidth && !store.isLoading && currentUnit != nil
    }

    var body: some View {
        ZStack {
            GjuhaAmbientBackground()

            ScrollView {
                Group {
                    if usesTwoColumns {
                        HStack(alignment: .top, spacing: .gjuha.loose) {
                            VStack(spacing: .gjuha.regular) {
                                contextRail
                            }
                            .frame(maxWidth: 360)

                            VStack(spacing: .gjuha.loose) {
                                lessonColumn
                            }
                        }
                        .padding(.horizontal, .gjuha.regular)
                        .padding(.vertical, .gjuha.loose)
                    } else {
                        singleColumn
                    }
                }
                // Keyed on what is actually being drawn, not on the width. Two
                // columns of cards are not prose, so the reading-measure cap
                // widens for them; the loading, empty and all-finished states
                // fall back to one column and keep the prose measure, which they
                // would otherwise lose on an iPad for no reason.
                .gjuhaReadableWidth(usesTwoColumns ? 1_040 : 620)
            }
        }
        // No title: Home draws its own header card. The bar itself is
        // hidden by the container, which is the only thing that can do it
        // without fighting the other three tabs for one navigation bar.
        .onAppear {
            if !animateEntrance {
                animateEntrance = true
            }
            store.send(.onAppear)
        }
    }

    /// Context: who the learner is today, what is due, and where they are in the
    /// course. Leads at every width.
    @ViewBuilder
    private var contextRail: some View {
        HomeHeaderView(stats: store.stats)

        if !store.isLoading, store.dueReviewCount > 0 {
            DailyReviewCard(count: store.dueReviewCount) {
                store.send(.startReviewTapped)
            }
        }

        if let unit = currentUnit {
            UnitHeaderCard(
                unit: unit,
                completedUnits: completedUnitsCount,
                totalUnits: store.units.count
            )
        }

        if !store.isLoading {
            ExploreCultureCard { store.send(.exploreCultureTapped) }
        }
    }

    /// The lessons themselves, and what comes after them.
    @ViewBuilder
    private var lessonColumn: some View {
        if let unit = currentUnit {
            CoursePathView(
                lessons: unit.lessons,
                onLessonTap: { lesson in
                    store.send(.lessonTapped(lesson))
                }
            )

            if let nextUnit = nextLockedUnit(after: unit) {
                NextUnitPreview(unit: nextUnit)
            }
        }
    }

    /// Compact width, and every state that has no map to put beside a rail:
    /// loading, no content, and everything finished.
    @ViewBuilder
    private var singleColumn: some View {
        VStack(spacing: .gjuha.regular) {
            HomeHeaderView(stats: store.stats)

            if !store.isLoading, store.dueReviewCount > 0 {
                DailyReviewCard(count: store.dueReviewCount) {
                    store.send(.startReviewTapped)
                }
            }

            if store.isLoading {
                ProgressView()
                    .padding(.top, .gjuha.hero)
            } else if let unit = currentUnit {
                UnitHeaderCard(
                    unit: unit,
                    completedUnits: completedUnitsCount,
                    totalUnits: store.units.count
                )

                CoursePathView(
                    lessons: unit.lessons,
                    onLessonTap: { lesson in
                        store.send(.lessonTapped(lesson))
                    }
                )

                if let nextUnit = nextLockedUnit(after: unit) {
                    NextUnitPreview(unit: nextUnit)
                }
            } else if store.units.isEmpty {
                HomeNoContentView()
            } else {
                AllCompleteView()
            }

            if !store.isLoading {
                ExploreCultureCard { store.send(.exploreCultureTapped) }
            }
        }
        .padding(.horizontal, .gjuha.regular)
        .padding(.top, .gjuha.snug)
        .padding(.bottom, .gjuha.section)
    }

    private func nextLockedUnit(after current: LearningUnit) -> LearningUnit? {
        guard let index = store.units.firstIndex(where: { $0.id == current.id }) else { return nil }
        let nextIndex = index + 1
        guard nextIndex < store.units.count else { return nil }
        return store.units[nextIndex]
    }
}

// MARK: - Header

/// Streak, today's goal, and lifetime XP.
///
/// The goal ring is the part that was missing. The learner picks a daily goal
/// during onboarding, it is saved, it is editable in Profile, and until now
/// nothing in the app ever showed progress against it: there was no way to know
/// whether today counted. The ring closes that loop, and it is the only place
/// `xpToday` surfaces, which is why the header takes whole stats rather than
/// two integers.
private struct HomeHeaderView: View {
    let stats: UserStats

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @State private var pulse = false

    var body: some View {
        // At accessibility text sizes three columns cannot share one line, so
        // the row becomes a column rather than truncating the numbers.
        let layout: AnyLayout = dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: .gjuha.snug))
            : AnyLayout(HStackLayout(alignment: .center, spacing: .gjuha.regular))

        layout {
            HeaderMetric(
                icon: "flame.fill",
                value: stats.currentStreak,
                tint: Color.gjuha.streakStrong,
                label: "Day streak",
                pulse: pulse,
                pulsePhase: 0
            )

            if !dynamicTypeSize.isAccessibilitySize {
                Spacer(minLength: 0)
            }

            DailyGoalRing(stats: stats)

            if !dynamicTypeSize.isAccessibilitySize {
                Spacer(minLength: 0)
            }

            HeaderMetric(
                icon: "star.fill",
                value: stats.totalXP,
                tint: Color.gjuha.xpStrong,
                label: "Total XP",
                pulse: pulse,
                pulsePhase: 0.3
            )
        }
        .padding(.horizontal, .gjuha.loose)
        .padding(.vertical, .gjuha.regular)
        .frame(maxWidth: .infinity)
        .gjuhaCardSurface(cornerRadius: GjuhaSpacing.Radius.large, prominence: .standard)
        .onAppear {
            if reduceMotion { return }
            pulse = true
        }
    }
}

private struct HeaderMetric: View {
    let icon: String
    let value: Int
    let tint: Color
    /// `LocalizedStringKey`, so the VoiceOver label reaches the String Catalog.
    let label: LocalizedStringKey
    let pulse: Bool
    /// Offsets this metric's breathing animation from the other's, so the two
    /// are not in lockstep.
    let pulsePhase: Double

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        HStack(spacing: .gjuha.hairline) {
            Image(systemName: icon)
                .foregroundStyle(tint)
                .scaleEffect(reduceMotion ? 1.0 : (pulse ? 1.12 : 0.95))
                .animation(
                    reduceMotion
                    ? .linear(duration: 0.01)
                    : .easeInOut(duration: 1.0).repeatForever(autoreverses: true).delay(pulsePhase),
                    value: pulse
                )
            Text(value, format: .number)
                .font(.gjuha.labelBold)
                .foregroundStyle(tint)
                .contentTransition(.numericText())
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(label)
        .accessibilityValue(Text(value, format: .number))
    }
}

/// Today's XP against the learner's chosen daily goal.
private struct DailyGoalRing: View {
    let stats: UserStats

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var shown: Double = 0

    private var isMet: Bool { stats.hasMetDailyGoal }

    var body: some View {
        HStack(spacing: .gjuha.tight) {
            ZStack {
                Circle()
                    .stroke(Color.gjuha.track, lineWidth: 5)

                Circle()
                    .trim(from: 0, to: shown)
                    // Flat, not a gradient. The old ring blended the accent
                    // into the streak colour, which made one object carry two
                    // brand colours and left the meaning of each weaker. The
                    // met state gradiented from success to success, which is
                    // a gradient reached for out of habit.
                    .stroke(
                        isMet ? Color.gjuha.success : Color.gjuha.accent,
                        style: StrokeStyle(lineWidth: 5, lineCap: .round)
                    )
                    // Start the arc at twelve o'clock, where a progress ring is
                    // read from, instead of three.
                    .rotationEffect(.degrees(-90))

                if isMet {
                    Image(systemName: "checkmark")
                        .font(.gjuha.symbol(13, .heavy))
                        .foregroundStyle(Color.gjuha.successStrong)
                } else {
                    Text(stats.xpToday, format: .number)
                        .font(.gjuha.captionBold)
                        .foregroundStyle(Color.gjuha.textPrimary)
                        .minimumScaleFactor(0.7)
                        .lineLimit(1)
                        .padding(2)
                }
            }
            .frame(width: 40, height: 40)

            VStack(alignment: .leading, spacing: 0) {
                Text("Today")
                    .font(.gjuha.caption)
                    .foregroundStyle(Color.gjuha.textSecondary)
                Text("\(stats.xpToday)/\(stats.dailyGoalXP) XP")
                    .font(.gjuha.captionBold)
                    .foregroundStyle(Color.gjuha.textPrimary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
        }
        .onAppear { animate(to: stats.dailyGoalProgress) }
        .onChange(of: stats.dailyGoalProgress) { _, new in animate(to: new) }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Today's goal")
        // Spoken as the real numbers plus whether the goal is met, because the
        // ring and the tick are both unavailable to VoiceOver.
        .accessibilityValue(
            isMet
            ? Text("Goal met. \(stats.xpToday) of \(stats.dailyGoalXP) XP")
            : Text("\(stats.xpToday) of \(stats.dailyGoalXP) XP")
        )
    }

    private func animate(to progress: Double) {
        guard !reduceMotion else {
            shown = progress
            return
        }
        withAnimation(.spring(response: 0.6, dampingFraction: 0.85)) {
            shown = progress
        }
    }
}

// MARK: - Daily Review Card

/// Surfaces spaced repetition reviews that are due, and starts a review session.
/// Only shown when at least one word is due, so it never nags with an empty queue.
private struct DailyReviewCard: View {
    let count: Int
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 14) {
                Image(systemName: "arrow.triangle.2.circlepath")
                    .font(.gjuha.symbol(26, .semibold))
                    .foregroundStyle(Color.gjuha.accentStrong)

                VStack(alignment: .leading, spacing: 4) {
                    Text("Daily review")
                        .font(.gjuha.headingSmall)
                        .foregroundStyle(Color.gjuha.textPrimary)
                    Text("\(count) words ready to strengthen")
                        .font(.gjuha.caption)
                        .foregroundStyle(Color.gjuha.textSecondary)
                        .lineLimit(2)
                }

                Spacer(minLength: 8)

                Image(systemName: "chevron.right")
                    .font(.gjuha.symbol(15, .bold))
                    .foregroundStyle(Color.gjuha.textTertiary)
            }
            .padding(16)
            .gjuhaCardSurface(cornerRadius: 20, prominence: .prominent)
        }
        .buttonStyle(.gjuhaCard)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Daily review")
        .accessibilityValue("\(count) words due for review")
        .accessibilityHint("Starts a spaced repetition review session")
        .accessibilityAddTraits(.isButton)
    }
}

// MARK: - Explore Culture Card

private struct ExploreCultureCard: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 14) {
                Image(systemName: "globe.europe.africa.fill")
                    .font(.gjuha.symbol(26, .semibold))
                    .foregroundStyle(Color.gjuha.accentStrong)

                VStack(alignment: .leading, spacing: 4) {
                    Text("Culture & dialects")
                        .font(.gjuha.headingSmall)
                        .foregroundStyle(Color.gjuha.textPrimary)
                    Text("Everyday situations and regional forms")
                        .font(.gjuha.caption)
                        .foregroundStyle(Color.gjuha.textSecondary)
                        .lineLimit(2)
                }

                Spacer(minLength: 8)

                Image(systemName: "chevron.right")
                    .font(.gjuha.symbol(15, .bold))
                    .foregroundStyle(Color.gjuha.textTertiary)
            }
            .padding(16)
            .gjuhaCardSurface(cornerRadius: 20, prominence: .prominent)
        }
        .buttonStyle(.gjuhaCard)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Culture and dialects")
        .accessibilityHint("Opens cultural units and regional forms")
        .accessibilityAddTraits(.isButton)
    }
}

// MARK: - Unit Header Card

private struct UnitHeaderCard: View {
    let unit: LearningUnit
    let completedUnits: Int
    let totalUnits: Int
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    private var completedLessons: Int {
        unit.lessons.filter(\.isCompleted).count
    }

    private var progress: Double {
        guard !unit.lessons.isEmpty else { return 0 }
        return Double(completedLessons) / Double(unit.lessons.count)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(unit.title)
                        .font(.gjuha.headingMedium)
                        .foregroundStyle(Color.gjuha.textPrimary)

                    Text(unit.description)
                        .font(.gjuha.caption)
                        .foregroundStyle(Color.gjuha.textSecondary)
                        .lineLimit(2)
                }

                Spacer(minLength: 8)
                AnimatedMascotView(size: 74)
            }

            // Progress bar
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text("\(completedLessons)/\(unit.lessons.count) lessons")
                        .font(.gjuha.captionBold)
                        .foregroundStyle(Color.gjuha.textPrimary)
                    Spacer()
                    // The brand colour is spent on the action and on status,
                    // not on a neutral figure. A unit at 0% rendered in the
                    // accent reads as a warning about the learner rather than
                    // as a fact about the unit, and every extra place the
                    // accent appears makes it mean less where it matters.
                    Text("\(Int(progress * 100))%")
                        .font(.gjuha.captionBold)
                        .foregroundStyle(
                            progress > 0 ? Color.gjuha.accentStrong : Color.gjuha.textSecondary
                        )
                }

                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule(style: .continuous)
                            .fill(Color.gjuha.track)
                            .frame(height: 8)
                        Capsule(style: .continuous)
                            .fill(
                                Color.gjuha.accent
                            )
                            .frame(width: geo.size.width * progress, height: 8)
                    }
                }
                .frame(height: 8)
            }

            // Course stats. At accessibility text sizes the three pills no longer
            // fit on one line, so the row stacks vertically (full labels, no
            // truncation) instead of ellipsizing.
            let chipLayout: AnyLayout = dynamicTypeSize.isAccessibilitySize
                ? AnyLayout(VStackLayout(alignment: .leading, spacing: 8))
                : AnyLayout(HStackLayout(spacing: 8))
            chipLayout {
                HomeMetricChip(icon: "checkmark.seal.fill", text: "\(completedUnits)/\(totalUnits) units")
                HomeMetricChip(icon: "book.closed.fill", text: "\(unit.lessons.count) lessons")
                // A CEFR code needs no translation, so it is built from a runtime
                // string deliberately rather than extracted as a catalog key.
                HomeMetricChip(icon: "graduationcap.fill", text: LocalizedStringKey(unit.cefrLevel.rawValue.uppercased()))
            }
        }
        .padding(16)
        .gjuhaCardSurface(cornerRadius: 22, prominence: .standard)
    }
}

// MARK: - Course Path (Duolingo-style zigzag)

private struct CoursePathView: View {
    let lessons: [LessonSummary]
    let onLessonTap: (LessonSummary) -> Void

    var body: some View {
        VStack(spacing: 0) {
            ForEach(Array(lessons.enumerated()), id: \.element.id) { index, lesson in
                VStack(spacing: 0) {
                    // Connector line
                    if index > 0 {
                        PathConnector(
                            isCompleted: lessons[index - 1].isCompleted,
                            fromOffset: zigzagOffset(for: index - 1),
                            toOffset: zigzagOffset(for: index)
                        )
                    }

                    // Lesson node
                    CourseNodeView(
                        lesson: lesson,
                        index: index,
                        isNext: isNextLesson(index),
                        onTap: { onLessonTap(lesson) }
                    )
                    .offset(x: zigzagOffset(for: index))
                }
            }
        }
        .padding(.vertical, 8)
    }

    private func zigzagOffset(for index: Int) -> CGFloat {
        let pattern: [CGFloat] = [0, 60, 0, -60]
        return pattern[index % pattern.count]
    }

    private func isNextLesson(_ index: Int) -> Bool {
        // The "next" lesson is the first non-completed, non-locked one
        let lesson = lessons[index]
        guard !lesson.isCompleted && !lesson.isLocked else { return false }
        return !lessons.prefix(index).contains(where: { !$0.isCompleted && !$0.isLocked })
    }
}

// MARK: - Path Connector

private struct PathConnector: View {
    let isCompleted: Bool
    let fromOffset: CGFloat
    let toOffset: CGFloat

    var body: some View {
        GeometryReader { geo in
            Path { path in
                let midY = geo.size.height / 2
                let centerX = geo.size.width / 2
                path.move(to: CGPoint(x: centerX + fromOffset, y: 0))
                path.addCurve(
                    to: CGPoint(x: centerX + toOffset, y: geo.size.height),
                    control1: CGPoint(x: centerX + fromOffset, y: midY),
                    control2: CGPoint(x: centerX + toOffset, y: midY)
                )
            }
            .stroke(
                isCompleted ? Color.gjuha.success.opacity(0.6) : Color.gjuha.textTertiary.opacity(0.3),
                style: StrokeStyle(lineWidth: 3, lineCap: .round, dash: isCompleted ? [] : [6, 4])
            )
        }
        .frame(height: 32)
    }
}

// MARK: - Course Node (Single Lesson)

private struct CourseNodeView: View {
    let lesson: LessonSummary
    let index: Int
    let isNext: Bool
    let onTap: () -> Void
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var breathe = false
    @State private var appeared = false

    private var nodeSize: CGFloat {
        isNext ? 72 : 60
    }

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 6) {
                ZStack {
                    // Glow ring for next lesson
                    if isNext {
                        Circle()
                            .fill(Color.gjuha.accent.opacity(0.3))
                            .frame(width: nodeSize + 16, height: nodeSize + 16)
                            .scaleEffect(reduceMotion ? 1.0 : (breathe ? 1.15 : 1.0))
                            .opacity(reduceMotion ? 0.75 : (breathe ? 0.5 : 1.0))
                    }

                    // Main circle
                    Circle()
                        .fill(backgroundColor)
                        .frame(width: nodeSize, height: nodeSize)
                        .overlay(
                            Circle()
                                .stroke(borderColor, lineWidth: isNext ? 3 : 2)
                        )
                        .shadow(
                            color: lesson.isCompleted
                                ? Color.gjuha.success.opacity(0.3)
                                : (isNext ? Color.gjuha.accent.opacity(0.4) : .clear),
                            radius: 8, y: 4
                        )

                    // Icon
                    if lesson.isLocked {
                        Image(systemName: "lock.fill")
                            .font(.gjuha.symbol(22, .semibold))
                            .foregroundStyle(Color.gjuha.textTertiary)
                    } else if lesson.isCompleted {
                        Image(systemName: "checkmark")
                            .font(.gjuha.symbol(24, .bold))
                            .foregroundStyle(Color.gjuha.onAccent)
                    } else {
                        Image(systemName: lesson.iconName)
                            .font(.gjuha.symbol(isNext ? 26 : 22, .semibold))
                            .foregroundStyle(isNext ? Color.gjuha.onAccent : Color.gjuha.textPrimary)
                    }
                }

                Text(lesson.title)
                    .font(isNext ? .gjuha.labelBold : .gjuha.caption)
                    .foregroundStyle(
                        lesson.isLocked
                            ? Color.gjuha.textTertiary
                            : Color.gjuha.textPrimary
                    )
                    .multilineTextAlignment(.center)
                    .lineLimit(2)

                if lesson.isCompleted && lesson.bestXP > 0 {
                    HStack(spacing: 2) {
                        Image(systemName: "star.fill")
                            .font(.gjuha.symbol(9, .regular))
                        Text(lesson.bestXP, format: .number)
                            .font(.gjuha.caption)
                    }
                    .foregroundStyle(Color.gjuha.xpStrong)
                }
            }
        }
        .buttonStyle(.gjuhaCard)
        .disabled(lesson.isLocked)
        .opacity(appeared ? 1 : 0)
        .offset(y: appeared ? 0 : 12)
        .onAppear {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.8).delay(Double(index) * 0.06)) {
                appeared = true
            }
            if isNext, !reduceMotion {
                withAnimation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true)) {
                    breathe = true
                }
            }
        }
    }

    private var backgroundColor: some ShapeStyle {
        // Flat fills. The node is the one place on this screen where the brand
        // colour is spent on something a learner acts on, so it is spent whole
        // rather than faded into a second colour.
        //
        // It is also better for the white glyph sitting on it: the accent
        // carries white at 6.62:1, while the streak end of the old gradient
        // measured 4.90:1, so the contrast varied across the same circle.
        if lesson.isCompleted {
            return AnyShapeStyle(Color.gjuha.success)
        }
        if isNext {
            return AnyShapeStyle(Color.gjuha.accent)
        }
        if lesson.isLocked {
            return AnyShapeStyle(Color.gjuha.surfaceSecondary.opacity(0.5))
        }
        return AnyShapeStyle(Color.gjuha.surface)
    }

    private var borderColor: Color {
        if lesson.isCompleted { return Color.gjuha.success }
        if isNext { return Color.gjuha.accent }
        if lesson.isLocked { return Color.gjuha.textTertiary.opacity(0.3) }
        return Color.gjuha.border
    }
}

// MARK: - Next Unit Preview

private struct NextUnitPreview: View {
    let unit: LearningUnit

    var body: some View {
        VStack(spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: "lock.fill")
                    .font(.gjuha.symbol(14, .semibold))
                    .foregroundStyle(Color.gjuha.textTertiary)
                Text("Next: \(unit.title)")
                    .font(.gjuha.labelBold)
                    .foregroundStyle(Color.gjuha.textTertiary)
            }
            Text("Complete all lessons above to unlock")
                .font(.gjuha.caption)
                .foregroundStyle(Color.gjuha.textTertiary.opacity(0.7))
        }
        .frame(maxWidth: .infinity)
        .padding(16)
        .background(Color.gjuha.surfaceSecondary.opacity(0.3))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(style: StrokeStyle(lineWidth: 1, dash: [6, 4]))
                .foregroundStyle(Color.gjuha.textTertiary.opacity(0.3))
        )
    }
}

// MARK: - Utility Views

private struct HomeMetricChip: View {
    let icon: String
    let text: LocalizedStringKey

    var body: some View {
        HStack(spacing: 5) {
            Image(systemName: icon)
                .font(.gjuha.symbol(11, .semibold))
            Text(text)
                .font(.gjuha.captionBold)
                .lineLimit(1)
        }
        .foregroundStyle(Color.gjuha.textSecondary)
        .padding(.horizontal, 9)
        .padding(.vertical, 6)
        .background(Color.gjuha.chipFill)
        .clipShape(Capsule(style: .continuous))
    }
}

private struct HomeNoContentView: View {
    var body: some View {
        VStack(spacing: 10) {
            AnimatedMascotView(size: 84)
            Text("Content pack is loading")
                .font(.gjuha.headingSmall)
                .foregroundStyle(Color.gjuha.textPrimary)
            Text("Your first unit will appear here in a moment.")
                .font(.gjuha.caption)
                .foregroundStyle(Color.gjuha.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(18)
        .gjuhaCardSurface(cornerRadius: 20, prominence: .standard)
    }
}

private struct AllCompleteView: View {
    var body: some View {
        VStack(spacing: 16) {
            AnimatedMascotView(size: 100)
            Text("You've completed everything!")
                .font(.gjuha.headingMedium)
                .foregroundStyle(Color.gjuha.textPrimary)
            Text("More content coming soon. Review your lessons to keep your skills sharp.")
                .font(.gjuha.bodyRegular)
                .foregroundStyle(Color.gjuha.textSecondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(24)
        .gjuhaCardSurface(cornerRadius: 22, prominence: .standard)
    }
}
