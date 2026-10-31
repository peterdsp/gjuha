import WidgetKit
import SwiftUI

/// The Home Screen and Lock Screen widget.
///
/// It answers one question at a glance: is there anything to do today? Streak and
/// XP are context, the due count and the next lesson are the call to action.
///
/// Every number comes from the projection the app writes, which is derived from
/// the same stores the Profile screen reads. The widget never estimates: when the
/// projection is stale (see `GjuhaEntry.isStale`) it hides counts rather than
/// showing a figure it cannot stand behind.
struct GjuhaProgressWidget: Widget {
    private let kind = "GjuhaProgressWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: GjuhaTimelineProvider()) { entry in
            GjuhaProgressWidgetView(entry: entry)
                .containerBackground(for: .widget) {
                    WidgetPalette.background
                }
        }
        .configurationDisplayName("Albanian Progress")
        .description("Your streak, the words due for review, and the next lesson waiting for you.")
        .supportedFamilies([
            .systemSmall,
            .systemMedium,
            .accessoryCircular,
            .accessoryRectangular,
            .accessoryInline
        ])
    }
}

// MARK: - Family router

struct GjuhaProgressWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: GjuhaEntry

    var body: some View {
        switch family {
        case .systemSmall:
            SmallWidgetView(entry: entry)
        case .systemMedium:
            MediumWidgetView(entry: entry)
        case .accessoryCircular:
            CircularAccessoryView(entry: entry)
        case .accessoryRectangular:
            RectangularAccessoryView(entry: entry)
        case .accessoryInline:
            InlineAccessoryView(entry: entry)
        default:
            // A family we did not declare support for. Render the small layout
            // rather than an empty view, so an unexpected context still shows
            // something useful.
            SmallWidgetView(entry: entry)
        }
    }
}

// MARK: - Shared call to action

/// What the widget asks the learner to do, and where tapping it goes.
///
/// Keeping this in one place means the small, medium, and Lock Screen layouts can
/// never disagree about what is due or where a tap leads.
private struct CallToAction {
    let headline: LocalizedStringResource
    let link: GjuhaDeepLink
    let symbol: String

    init(entry: GjuhaEntry) {
        if entry.isPlaceholder {
            headline = "Open Gjuha to begin"
            link = .continueLearning
            symbol = "bolt.fill"
        } else if entry.isStale {
            // Counts cannot be trusted across a day boundary, so do not quote one.
            headline = "Check today's review"
            link = .startReview
            symbol = "arrow.triangle.2.circlepath"
        } else if entry.snapshot.dueReviewCount > 0 {
            headline = "\(entry.snapshot.dueReviewCount) words due"
            link = .startReview
            symbol = "arrow.triangle.2.circlepath"
        } else if let next = entry.snapshot.nextLessonTitle {
            headline = "Next: \(next)"
            link = .continueLearning
            symbol = "bolt.fill"
        } else if entry.snapshot.practicedToday {
            headline = "Done for today"
            link = .progress
            symbol = "checkmark.seal.fill"
        } else {
            headline = "Nothing due. Keep going."
            link = .continueLearning
            symbol = "bolt.fill"
        }
    }
}

// MARK: - Home Screen, small

private struct SmallWidgetView: View {
    let entry: GjuhaEntry

    var body: some View {
        let action = CallToAction(entry: entry)

        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: "flame.fill")
                    .foregroundStyle(WidgetPalette.streak)
                    .imageScale(.small)
                Text(streakText)
                    .font(.system(.subheadline, design: .rounded, weight: .bold))
                    .foregroundStyle(WidgetPalette.textPrimary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)

                Spacer(minLength: 0)

                // Only when the projection is current and a goal has been
                // written. A stale snapshot's XP belongs to a day that has
                // already turned, and a pre-update snapshot has no goal at all,
                // so in both cases the ring is omitted rather than guessed at.
                if !entry.isPlaceholder, !entry.isStale, entry.snapshot.dailyGoalXP > 0 {
                    DailyGoalDot(snapshot: entry.snapshot)
                }
            }

            Spacer(minLength: 0)

            // Scales with the text beside it. The accessory families below
            // keep fixed sizes on purpose: the system sets their container and
            // it cannot grow, so a scaling glyph would be clipped rather than
            // read more easily.
            Image(systemName: action.symbol)
                .font(.system(.title3, weight: .semibold))
                .foregroundStyle(WidgetPalette.accent)

            Text(action.headline)
                .font(.system(.footnote, design: .rounded, weight: .semibold))
                .foregroundStyle(WidgetPalette.textPrimary)
                .lineLimit(2)
                .minimumScaleFactor(0.8)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .widgetURL(action.link.url)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(Text("Gjuha"))
        .accessibilityValue(Text(action.headline))
    }

    /// The streak is only shown as a number when the projection is current.
    private var streakText: LocalizedStringResource {
        guard !entry.isPlaceholder, !entry.isStale else { return "Gjuha" }
        let streak = entry.snapshot.currentStreak
        return streak == 0 ? "No streak yet" : "\(streak) day streak"
    }
}

// MARK: - Home Screen, medium

private struct MediumWidgetView: View {
    let entry: GjuhaEntry

    var body: some View {
        let action = CallToAction(entry: entry)
        let showCounts = !entry.isPlaceholder && !entry.isStale

        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: action.symbol)
                    .font(.system(.callout, weight: .semibold))
                    .foregroundStyle(WidgetPalette.accent)

                Text(action.headline)
                    .font(.system(.headline, design: .rounded, weight: .bold))
                    .foregroundStyle(WidgetPalette.textPrimary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)

                Spacer(minLength: 0)
            }

            if showCounts {
                HStack(spacing: 0) {
                    StatCell(
                        symbol: "flame.fill",
                        tint: WidgetPalette.streak,
                        value: entry.snapshot.currentStreak,
                        caption: "Day streak"
                    )
                    // Today's goal rather than the lifetime total: a number
                    // that can still change today is the one worth a glance.
                    StatCell(
                        symbol: "star.fill",
                        tint: WidgetPalette.xp,
                        value: entry.snapshot.xpToday,
                        caption: entry.snapshot.dailyGoalXP > 0
                            ? "of \(entry.snapshot.dailyGoalXP) XP today"
                            : "XP today"
                    )
                    StatCell(
                        symbol: "checkmark.seal.fill",
                        tint: WidgetPalette.success,
                        value: entry.snapshot.wordsMastered,
                        caption: "Mastered"
                    )
                }
            } else {
                Text(entry.isStale
                     ? "Open Gjuha for today's numbers."
                     : "Your streak and reviews will appear here.")
                    .font(.system(.footnote, design: .rounded))
                    .foregroundStyle(WidgetPalette.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .widgetURL(action.link.url)
    }
}

/// One figure in the medium widget. "Mastered" is the scheduler's documented
/// mastery interval, the same definition the Profile screen uses.
private struct StatCell: View {
    let symbol: String
    let tint: Color
    let value: Int
    let caption: LocalizedStringResource

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 3) {
                Image(systemName: symbol)
                    .imageScale(.small)
                    .foregroundStyle(tint)
                Text(value, format: .number)
                    .font(.system(.subheadline, design: .rounded, weight: .bold))
                    .foregroundStyle(WidgetPalette.textPrimary)
                    .contentTransition(.numericText())
            }
            // 11 points is Apple's floor for widget text: "display text using
            // fonts at 11 points or larger. Text in a font that's smaller than
            // 11 points can be too hard for many people to read." This caption
            // was 10. Using the caption2 style rather than a fixed size also
            // lets it follow Dynamic Type, which widgets support from Large to
            // AX5.
            Text(caption)
                .font(.system(.caption2, design: .rounded, weight: .medium))
                .foregroundStyle(WidgetPalette.textSecondary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(Text(caption))
        .accessibilityValue(Text(value, format: .number))
    }
}

// MARK: - Daily goal

/// A compact ring for today's XP against the goal.
///
/// Drawn rather than using `Gauge`, because the small Home Screen family renders
/// a gauge at a size that crowds the streak line next to it.
private struct DailyGoalDot: View {
    let snapshot: GjuhaWidgetSnapshot

    var body: some View {
        ZStack {
            Circle()
                .stroke(WidgetPalette.track, lineWidth: 3.5)
            Circle()
                .trim(from: 0, to: snapshot.dailyGoalProgress)
                .stroke(
                    snapshot.hasMetDailyGoal ? WidgetPalette.successFill : WidgetPalette.accentFill,
                    style: StrokeStyle(lineWidth: 3.5, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))

            if snapshot.hasMetDailyGoal {
                // A glyph, so the 11 point text floor does not apply, but it
                // still scales with the text beside it rather than staying
                // pinned while that grows.
                Image(systemName: "checkmark")
                    .font(.system(.caption2, weight: .heavy))
                    .foregroundStyle(WidgetPalette.success)
            }
        }
        .frame(width: 22, height: 22)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("Today's goal"))
        .accessibilityValue(
            Text("\(snapshot.xpToday) of \(snapshot.dailyGoalXP) XP")
        )
    }
}

// MARK: - Lock Screen

/// Lock Screen accessory families are rendered monochrome by the system, so these
/// use no colour and lean on shape and weight instead.
private struct CircularAccessoryView: View {
    let entry: GjuhaEntry

    var body: some View {
        let action = CallToAction(entry: entry)
        let showCount = !entry.isPlaceholder && !entry.isStale

        ZStack {
            if showCount, entry.snapshot.dueReviewCount > 0 {
                AccessoryWidgetBackground()
                VStack(spacing: -2) {
                    Text(entry.snapshot.dueReviewCount, format: .number)
                        .font(.system(.title3, design: .rounded, weight: .bold))
                    // Was 9 points, below the widget floor.
                    Text("due")
                        .font(.system(.caption2, design: .rounded, weight: .medium))
                }
            } else if showCount, entry.snapshot.dailyGoalXP > 0 {
                // Nothing due, but today's goal is still open or just met. A
                // capacity gauge is the family's own idiom and renders correctly
                // under the system's monochrome treatment, which a hand drawn
                // ring in brand colour does not.
                Gauge(value: entry.snapshot.dailyGoalProgress) {
                    Image(systemName: "star.fill")
                } currentValueLabel: {
                    Image(systemName: entry.snapshot.hasMetDailyGoal ? "checkmark" : "star.fill")
                        .font(.system(size: 13, weight: .bold))
                }
                .gaugeStyle(.accessoryCircularCapacity)
            } else {
                AccessoryWidgetBackground()
                Image(systemName: showCount ? "checkmark" : "character.book.closed.fill")
                    .font(.system(size: 16, weight: .semibold))
            }
        }
        .widgetURL(action.link.url)
        .accessibilityLabel(Text("Gjuha"))
        .accessibilityValue(Text(action.headline))
    }
}

private struct RectangularAccessoryView: View {
    let entry: GjuhaEntry

    var body: some View {
        let action = CallToAction(entry: entry)

        VStack(alignment: .leading, spacing: 1) {
            Text("Gjuha")
                .font(.system(.caption, design: .rounded, weight: .bold))
                .widgetAccentable()
            Text(action.headline)
                .font(.system(.caption2, design: .rounded))
                .lineLimit(2)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .widgetURL(action.link.url)
    }
}

private struct InlineAccessoryView: View {
    let entry: GjuhaEntry

    var body: some View {
        let action = CallToAction(entry: entry)
        // Inline accessories get a single line and one optional symbol.
        Label {
            Text(action.headline)
        } icon: {
            Image(systemName: action.symbol)
        }
        .widgetURL(action.link.url)
    }
}
