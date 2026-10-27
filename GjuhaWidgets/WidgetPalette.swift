import SwiftUI

/// Colour accessors for the widget extension.
///
/// The colour *values* are not duplicated here. They live once in
/// `Gjuha/Resources/Palette.xcassets`, which both the app and this extension
/// include, so the widget and the app can never drift to different reds. This file
/// is only the thin accessor, because the app's `GjuhaColors` lives in a file that
/// also pulls in WebKit and the animated mascot, which a widget has no business
/// linking.
///
/// `Color(_:)` with no bundle resolves against `Bundle.main`, which for an app
/// extension is the extension's own bundle, so the palette must be a resource of
/// this target.
enum WidgetPalette {
    static let accent = Color("Accent")
    static let background = Color("Background")
    static let surface = Color("Surface")
    static let textPrimary = Color("TextPrimary")
    static let textSecondary = Color("TextSecondary")
    static let streak = Color("Streak")
    static let xp = Color("XP")
    static let success = Color("Success")
}
