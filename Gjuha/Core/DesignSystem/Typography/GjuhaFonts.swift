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
    var displayLarge: Font { Self.scaled(48, .black, .rounded, relativeTo: .largeTitle) }
    var displayMedium: Font { Self.scaled(36, .bold, .rounded, relativeTo: .largeTitle) }

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
    var exercisePrompt: Font { Self.scaled(26, .semibold, .rounded, relativeTo: .title1) }

    // Keyboard / answer option
    var answerOption: Font { Self.scaled(18, .medium, .rounded, relativeTo: .body) }

    /// Builds a Dynamic Type aware `Font` that starts at `size` and scales with
    /// the given text style. Preserves weight and (rounded/default) design.
    static func scaled(
        _ size: CGFloat,
        _ weight: UIFont.Weight,
        _ design: UIFontDescriptor.SystemDesign,
        relativeTo textStyle: UIFont.TextStyle
    ) -> Font {
        let base = UIFont.systemFont(ofSize: size, weight: weight)
        let descriptor = base.fontDescriptor.withDesign(design) ?? base.fontDescriptor
        let uiFont = UIFont(descriptor: descriptor, size: size)
        let scaled = UIFontMetrics(forTextStyle: textStyle).scaledFont(for: uiFont)
        return Font(scaled)
    }
}
