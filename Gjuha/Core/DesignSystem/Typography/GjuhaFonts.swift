import SwiftUI

// MARK: - Font Namespace

extension Font {
    static let gjuha = GjuhaFonts()
}

struct GjuhaFonts {
    // Display (hero screens, onboarding)
    var displayLarge: Font { .system(size: 48, weight: .black, design: .rounded) }
    var displayMedium: Font { .system(size: 36, weight: .bold, design: .rounded) }

    // Headings
    var headingLarge: Font { .system(size: 28, weight: .bold, design: .rounded) }
    var headingMedium: Font { .system(size: 22, weight: .semibold, design: .rounded) }
    var headingSmall: Font { .system(size: 18, weight: .semibold, design: .rounded) }

    // Body
    var bodyRegular: Font { .system(size: 16, weight: .regular, design: .default) }
    var bodyMedium: Font { .system(size: 16, weight: .medium, design: .default) }

    // Labels
    var labelBold: Font { .system(size: 14, weight: .semibold, design: .default) }
    var labelRegular: Font { .system(size: 14, weight: .regular, design: .default) }

    // Caption / small
    var caption: Font { .system(size: 12, weight: .regular, design: .default) }
    var captionBold: Font { .system(size: 12, weight: .semibold, design: .default) }

    // Exercise prompt (prominent)
    var exercisePrompt: Font { .system(size: 26, weight: .semibold, design: .rounded) }

    // Keyboard / answer option
    var answerOption: Font { .system(size: 18, weight: .medium, design: .rounded) }
}
