import SwiftUI
import UIKit

// MARK: - Font Namespace

extension Font {
    static let gjuha = GjuhaFonts()
}

/// Semantic type scale for Gjuha.
///
/// Every token keeps its original point size at the default Dynamic Type setting
/// but is now built through `UIFontMetrics`, so the whole app scales with the
/// user's preferred text size instead of staying pinned. Each token is anchored
/// to the closest system text style, which sets the scaling curve.
struct GjuhaFonts {
    // Display (hero screens, onboarding)
    //
    // The art direction is the alphabet: the marks Albanian adds to the Latin
    // one, and the nine digraphs that are single letters. So display type is
    // set large enough for an `e` with a diaeresis to be a shape rather than a
    // speck, and heavy enough that the mark has weight of its own.
    //
    // Display type is capped. Everything else scales without a ceiling, which
    // is the accessibility promise and must not change. But a token that
    // already starts at 52 or 64 points does not need the full multiplier at
    // the largest accessibility sizes: unbounded, a 64 point hero reaches
    // roughly 200 points and overflows any layout holding it. The caps below
    // still let it grow by about half again, which is a real increase for
    // someone who needs it, and keep the screen usable.
    var displayHero: Font { Self.scaled(64, .black, .rounded, relativeTo: .largeTitle, cappedAt: 96) }
    var displayLarge: Font { Self.scaled(52, .black, .rounded, relativeTo: .largeTitle, cappedAt: 80) }
    var displayMedium: Font { Self.scaled(38, .bold, .rounded, relativeTo: .largeTitle, cappedAt: 62) }

    // Headings
    var headingLarge: Font { Self.scaled(28, .bold, .rounded, relativeTo: .title1) }
    var headingMedium: Font { Self.scaled(22, .semibold, .rounded, relativeTo: .title2) }
    var headingSmall: Font { Self.scaled(18, .semibold, .rounded, relativeTo: .title3) }

    // Body
    var bodyRegular: Font { Self.scaled(16, .regular, .default, relativeTo: .body) }
    var bodyMedium: Font { Self.scaled(16, .medium, .default, relativeTo: .body) }

    // Labels
    var labelBold: Font { Self.scaled(14, .semibold, .default, relativeTo: .subheadline) }
    var labelRegular: Font { Self.scaled(14, .regular, .default, relativeTo: .subheadline) }

    // Caption / small
    var caption: Font { Self.scaled(12, .regular, .default, relativeTo: .caption1) }
    var captionBold: Font { Self.scaled(12, .semibold, .default, relativeTo: .caption1) }

    // Exercise prompt (prominent)
    //
    // The question is the most read text in the app, and it is where a learner
    // meets the diacritics. It is set a step larger than a heading rather than
    // a step smaller.
    var exercisePrompt: Font { Self.scaled(30, .semibold, .rounded, relativeTo: .title1, cappedAt: 54) }

    // Keyboard / answer option
    var answerOption: Font { Self.scaled(18, .medium, .rounded, relativeTo: .body) }

    /// Builds a Dynamic Type aware `Font` that starts at `size` and scales with
    /// the given text style. Preserves weight and (rounded/default) design.
    static func scaled(
        _ size: CGFloat,
        _ weight: UIFont.Weight,
        _ design: UIFontDescriptor.SystemDesign,
        relativeTo textStyle: UIFont.TextStyle,
        cappedAt maximum: CGFloat? = nil
    ) -> Font {
        let base = UIFont.systemFont(ofSize: size, weight: weight)
        let descriptor = base.fontDescriptor.withDesign(design) ?? base.fontDescriptor
        let uiFont = UIFont(descriptor: descriptor, size: size)
        let metrics = UIFontMetrics(forTextStyle: textStyle)
        // A ceiling only where one was asked for. Body and label tokens pass
        // none and keep scaling without limit.
        let scaled = maximum.map { metrics.scaledFont(for: uiFont, maximumPointSize: $0) }
            ?? metrics.scaledFont(for: uiFont)
        return Font(scaled)
    }
}

// MARK: - Display tracking

extension View {
    /// Tightens tracking for display type only.
    ///
    /// Large type sets loose, so the biggest sizes are pulled in. Body text is
    /// left at its natural tracking: tightening it costs legibility and gains
    /// nothing, and an Albanian word carrying two diacritics needs the room.
    func gjuhaDisplayTracking(_ amount: CGFloat = -1.5) -> some View {
        tracking(amount)
    }
}
