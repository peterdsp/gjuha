import SwiftUI

/// Colour accessors for the widget extension.
///
/// The colour *values* are not duplicated here. They live once in
/// `Gjuha/Resources/Palette.xcassets`, which both the app and this extension
/// include, so the widget and the app can never drift to different reds. This file
/// is only the thin accessor, because the app's `GjuhaColors` lives in a file that
/// is part of the app's SwiftUI design-system code, which a widget has no
/// business compiling.
///
/// `Color(_:)` with no bundle resolves against `Bundle.main`, which for an app
/// extension is the extension's own bundle, so the palette must be a resource of
/// this target.
enum WidgetPalette {
    static let background = Color("Background")
    static let surface = Color("Surface")
    static let textPrimary = Color("TextPrimary")
    static let textSecondary = Color("TextSecondary")

    // Fills, for a shape that carries a foreground.
    static let accentFill = Color("Accent")
    static let streakFill = Color("Streak")
    static let xpFill = Color("XP")
    static let successFill = Color("Success")
    static let track = Color("Track")

    // On-surface members, for an icon or a number drawn on the widget
    // background. The widget was tinting its symbols and figures with the fill
    // colours, which measure as low as 1.76:1 against `Background`; these are
    // the same tokens the app switched to for the same reason.
    static let accent = Color("AccentStrong")
    static let streak = Color("StreakStrong")
    static let xp = Color("XPStrong")
    static let success = Color("SuccessStrong")

    // Foreground on a fill.
    static let onAccent = Color("OnAccent")
    static let onWarning = Color("OnWarning")
}
