import SwiftUI

// MARK: - Spacing Namespace

extension CGFloat {
    static let gjuha = GjuhaSpacing()
}

/// The 4pt spacing grid the project mandates, as named steps.
///
/// The grid was a documented rule with nothing to enforce it, so views carried
/// literals like `padding(9)`, `spacing: 14` and `padding(.vertical, 6)` that are
/// off-grid by one or two points. Those are invisible individually and add up to
/// rows that do not line up with the rows above them.
///
/// Steps are named by role rather than by number, so a call site says what the
/// gap is for. `GjuhaSpacingTests` asserts every step is a multiple of 4.
struct GjuhaSpacing {
    /// 4pt. Between an icon and its own label.
    let hairline: CGFloat = 4
    /// 8pt. Between tightly related lines in one block.
    let tight: CGFloat = 8
    /// 12pt. Between controls in a row, and a chip's own padding.
    let snug: CGFloat = 12
    /// 16pt. The default: card padding, screen gutter, gap between cards.
    let regular: CGFloat = 16
    /// 24pt. Between distinct groups inside one screen.
    let loose: CGFloat = 24
    /// 32pt. Around a hero element.
    let section: CGFloat = 32
    /// 48pt. Above a screen's primary action, and below a celebration.
    let hero: CGFloat = 48

    /// Every step, for the test that checks they stay on the grid.
    var allSteps: [CGFloat] { [hairline, tight, snug, regular, loose, section, hero] }
}

// MARK: - Corner Radii

extension GjuhaSpacing {
    /// Corner radii, kept here so a card and the stroke drawn over it cannot be
    /// given different values by accident, which leaves a visible sliver of
    /// stroke outside the fill.
    enum Radius {
        /// 10pt. Chips and small inline controls.
        static let small: CGFloat = 10
        /// 14pt. Compact cards, stat tiles.
        static let medium: CGFloat = 14
        /// 18pt. Settings and content cards.
        static let large: CGFloat = 18
        /// 22pt. The prominent card on a screen.
        static let prominent: CGFloat = 22
    }
}

// MARK: - Minimum Hit Target

extension GjuhaSpacing {
    /// 44pt, Apple's minimum comfortable hit target on iOS.
    ///
    /// Several controls in this app are visually smaller than this (a chip, an
    /// exit button, a filter pill). Applying this as a `frame(minWidth:minHeight:)`
    /// on the button's content keeps the tappable area honest without changing
    /// how the control looks.
    static let minimumHitTarget: CGFloat = 44
}

extension View {
    /// Guarantees a control is at least 44x44pt to touch, whatever its visual
    /// size. Apply inside a `Button` label, outside the visible shape.
    func gjuhaMinimumHitTarget() -> some View {
        frame(
            minWidth: GjuhaSpacing.minimumHitTarget,
            minHeight: GjuhaSpacing.minimumHitTarget
        )
    }
}
