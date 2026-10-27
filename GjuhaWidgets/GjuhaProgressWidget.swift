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
            HStack(spacing: 4) {
                Image(systemName: "flame.fill")
                    .foregroundStyle(WidgetPalette.streak)
                    .imageScale(.small)
                Text(streakText)
                    .font(.system(.subheadline, design: .rounded, weight: .bold))
                    .foregroundStyle(WidgetPalette.textPrimary)
            }

            Spacer(minLength: 0)

            Image(systemName: action.symbol)
                .font(.system(size: 20, weight: .semibold))
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
                    .font(.system(size: 16, weight: .semibold))
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
                    StatCell(
                        symbol: "star.fill",
                        tint: WidgetPalette.xp,
                        value: entry.snapshot.totalXP,
                        caption: "Total XP"
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
            Text(caption)
                .font(.system(size: 10, weight: .medium, design: .rounded))
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

// MARK: - Lock Screen

/// Lock Screen accessory families are rendered monochrome by the system, so these
/// use no colour and lean on shape and weight instead.
private struct CircularAccessoryView: View {
    let entry: GjuhaEntry

    var body: some View {
        let action = CallToAction(entry: entry)
        let showCount = !entry.isPlaceholder && !entry.isStale

        ZStack {
            AccessoryWidgetBackground()
            if showCount, entry.snapshot.dueReviewCount > 0 {
                VStack(spacing: -2) {
                    Text(entry.snapshot.dueReviewCount, format: .number)
                        .font(.system(.title3, design: .rounded, weight: .bold))
                    Text("due")
                        .font(.system(size: 9, weight: .medium, design: .rounded))
                }
            } else {
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
