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

    var body: some View {
        ZStack {
            GjuhaLiquidGlassBackground()

            ScrollView {
                VStack(spacing: 0) {
                    HomeHeaderView(streak: store.currentStreak, xp: store.totalXP)
                        .padding(.horizontal, 16)
                        .padding(.top, 12)

                    if !store.isLoading && store.dueReviewCount > 0 {
                        DailyReviewCard(count: store.dueReviewCount) {
                            store.send(.startReviewTapped)
                        }
                        .padding(.horizontal, 16)
                        .padding(.top, 16)
                    }

                    if store.isLoading {
                        ProgressView()
                            .padding(.top, 48)
                    } else if let unit = currentUnit {
                        VStack(spacing: 20) {
                            // Current unit header
                            UnitHeaderCard(
                                unit: unit,
                                completedUnits: completedUnitsCount,
                                totalUnits: store.units.count
                            )

                            // Course path - zigzag lesson nodes
                            CoursePathView(
                                lessons: unit.lessons,
                                onLessonTap: { lesson in
                                    store.send(.lessonTapped(lesson))
                                }
                            )

                            // Next unit preview
                            if let nextUnit = nextLockedUnit(after: unit) {
                                NextUnitPreview(unit: nextUnit)
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.top, 20)
                        .padding(.bottom, 28)
                    } else if store.units.isEmpty {
                        HomeNoContentView()
                            .padding(.horizontal, 16)
                            .padding(.top, 20)
                    } else {
                        // All units done!
                        AllCompleteView()
                            .padding(.horizontal, 16)
                            .padding(.top, 20)
                    }
                }
                .gjuhaReadableWidth()
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

    private func nextLockedUnit(after current: LearningUnit) -> LearningUnit? {
        guard let index = store.units.firstIndex(where: { $0.id == current.id }) else { return nil }
        let nextIndex = index + 1
        guard nextIndex < store.units.count else { return nil }
        return store.units[nextIndex]
    }
}

// MARK: - Header

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
        .onAppear { pulse = true }
    }
}

// MARK: - Daily Review Card

/// Surfaces spaced repetition reviews that are due, and starts a review session.
/// Only shown when at least one word is due, so it never nags with an empty queue.
private struct DailyReviewCard: View {
    let count: Int
    let action: () -> Void

    private var wordWord: String { count == 1 ? "word" : "words" }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 14) {
                Image(systemName: "arrow.triangle.2.circlepath")
                    .font(.system(size: 26, weight: .semibold))
                    .foregroundStyle(Color.gjuha.accent)

                VStack(alignment: .leading, spacing: 4) {
                    Text("Daily review")
                        .font(.gjuha.headingSmall)
                        .foregroundStyle(Color.gjuha.textPrimary)
                    Text("\(count) \(wordWord) ready to strengthen")
                        .font(.gjuha.caption)
                        .foregroundStyle(Color.gjuha.textSecondary)
                        .lineLimit(2)
                }

                Spacer(minLength: 8)

                Image(systemName: "chevron.right")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(Color.gjuha.textTertiary)
            }
            .padding(16)
            .gjuhaLiquidGlassCard(cornerRadius: 20, tintOpacity: 0.12)
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Daily review")
        .accessibilityValue("\(count) \(wordWord) due for review")
        .accessibilityHint("Starts a spaced repetition review session")
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
                    Text("\(Int(progress * 100))%")
                        .font(.gjuha.captionBold)
                        .foregroundStyle(Color.gjuha.accent)
                }

                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule(style: .continuous)
                            .fill(Color.white.opacity(0.2))
                            .frame(height: 8)
                        Capsule(style: .continuous)
                            .fill(
                                LinearGradient(
                                    colors: [Color.gjuha.accent, Color.gjuha.streak],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
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
                HomeMetricChip(icon: "graduationcap.fill", text: unit.cefrLevel.rawValue.uppercased())
            }
        }
        .padding(16)
        .gjuhaLiquidGlassCard(cornerRadius: 22, tintOpacity: 0.09)
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
                            .scaleEffect(breathe ? 1.15 : 1.0)
                            .opacity(breathe ? 0.5 : 1.0)
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
                            .font(.system(size: 22, weight: .semibold))
                            .foregroundStyle(Color.gjuha.textTertiary)
                    } else if lesson.isCompleted {
                        Image(systemName: "checkmark")
                            .font(.system(size: 24, weight: .bold))
                            .foregroundStyle(.white)
                    } else {
                        Image(systemName: lesson.iconName)
                            .font(.system(size: isNext ? 26 : 22, weight: .semibold))
                            .foregroundStyle(isNext ? .white : Color.gjuha.textPrimary)
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
                            .font(.system(size: 9))
                        Text("\(lesson.bestXP)")
                            .font(.system(size: 10, weight: .semibold))
                    }
                    .foregroundStyle(Color.gjuha.xp)
                }
            }
        }
        .buttonStyle(.plain)
        .disabled(lesson.isLocked)
        .opacity(appeared ? 1 : 0)
        .offset(y: appeared ? 0 : 12)
        .onAppear {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.8).delay(Double(index) * 0.06)) {
                appeared = true
            }
            if isNext {
                withAnimation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true)) {
                    breathe = true
                }
            }
        }
    }

    private var backgroundColor: some ShapeStyle {
        if lesson.isCompleted {
            return AnyShapeStyle(
                LinearGradient(
                    colors: [Color.gjuha.success, Color.gjuha.success.opacity(0.8)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
        }
        if isNext {
            return AnyShapeStyle(
                LinearGradient(
                    colors: [Color.gjuha.accent, Color.gjuha.streak.opacity(0.9)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
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
                    .font(.system(size: 14, weight: .semibold))
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
    let text: String

    var body: some View {
        HStack(spacing: 5) {
            Image(systemName: icon)
                .font(.system(size: 11, weight: .semibold))
            Text(text)
                .font(.gjuha.captionBold)
                .lineLimit(1)
        }
        .foregroundStyle(Color.gjuha.textSecondary)
        .padding(.horizontal, 9)
        .padding(.vertical, 6)
        .background(.white.opacity(0.15))
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
        .gjuhaLiquidGlassCard(cornerRadius: 20, tintOpacity: 0.07)
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
        .gjuhaLiquidGlassCard(cornerRadius: 22, tintOpacity: 0.09)
    }
}
