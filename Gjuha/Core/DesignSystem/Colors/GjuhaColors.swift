import SwiftUI

// MARK: - Color Namespace

extension Color {
    static let gjuha = GjuhaColors()
}

struct GjuhaColors {
    // Brand
    let accent = Color("Accent")          // Primary action color (deep red-orange)
    let accentSubtle = Color("AccentSubtle")  // Light tint of accent for backgrounds

    // Backgrounds
    let background = Color("Background")       // App background
    let surface = Color("Surface")             // Card / list item background
    let surfaceSecondary = Color("SurfaceSecondary")  // Subtle secondary surface

    // Text
    let textPrimary = Color("TextPrimary")
    let textSecondary = Color("TextSecondary")
    let textTertiary = Color("TextTertiary")

    // Semantic
    let success = Color("Success")
    let warning = Color("Warning")
    let error = Color("Error")

    // Gamification
    let streak = Color("Streak")      // Flame orange
    let xp = Color("XP")             // Gold/yellow

    // Borders
    let border = Color("Border")
}

// MARK: - Fallback Color Literals (for previews without asset catalog)

extension Color {
    static var gjuhaAccentFallback: Color { Color(red: 0.87, green: 0.26, blue: 0.21) }
    static var gjuhaBackgroundFallback: Color { Color(UIColor.systemBackground) }
    static var gjuhaSurfaceFallback: Color { Color(UIColor.secondarySystemBackground) }
}
