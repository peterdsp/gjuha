import SwiftUI

// MARK: - Prominence

/// How much a surface should stand off the page.
///
/// Replaces the old `tintOpacity:` parameter, which took values between 0.05 and
/// 0.12 across 32 call sites and encoded nothing: the numbers were picked by eye,
/// and no reader could tell what a 0.07 card was meant to be compared with a 0.08
/// one. These three levels say what the surface *is*.
enum GjuhaSurfaceProminence: Equatable, Sendable {
    /// A surface drawn inside another surface: a stat tile within a card, a chip
    /// within a row. Carries no material and no shadow.
    ///
    /// This is the level that fixes a real defect. A material inside a material
    /// is the "glass stacked on glass" case Apple warns about, where the second
    /// layer blurs the hierarchy the first one exists to create, and it also
    /// stacks two shadows that no physical arrangement would produce.
    case nested
    /// The default: a content card on the page.
    case standard
    /// The one surface on a screen that should be noticed first.
    case prominent
}

// MARK: - Resolution

/// What a surface actually draws, given its prominence and the accessibility
/// settings in force.
///
/// Split out as a value so the decision is a pure function that
/// `GjuhaSurfaceTests` can assert directly. A `ViewModifier` cannot be inspected
/// from a unit test, so without this the Reduce Transparency fallback would be a
/// claim with nothing behind it.
struct GjuhaSurfaceResolution: Equatable, Sendable {
    enum Fill: Equatable, Sendable {
        /// Fully opaque. The Reduce Transparency answer, and what a nested
        /// surface uses when it needs to be distinguishable.
        case opaqueSurface
        case opaqueSurfaceSecondary
        /// A standard material. Deliberately `regular`, not `ultraThin`: Apple's
        /// Materials guidance is that "thicker materials, which are more opaque,
        /// can provide better contrast for text and other elements with fine
        /// features", and every one of these surfaces is full of text.
        case regularMaterial
        /// A token tint with no material behind it.
        case chipFill
    }

    let fill: Fill
    let hasShadow: Bool
    let strokeWidth: CGFloat

    /// Whether this resolution puts any translucency on screen. Used by the
    /// test that checks Reduce Transparency leaves none.
    var isTranslucent: Bool {
        switch fill {
        case .regularMaterial, .chipFill: true
        case .opaqueSurface, .opaqueSurfaceSecondary: false
        }
    }
}

enum GjuhaSurfaceStyle {
    /// Resolves what to draw.
    ///
    /// Three settings feed in, and each has a documented reason to:
    ///
    /// - **Reduce Transparency** removes every material and tint. Before this
    ///   existed, the app had no answer for the setting at all: roughly thirty
    ///   surfaces were built on a material and none of them checked it.
    /// - **Increase Contrast** thickens the edge. The `hairline` token already
    ///   carries a stronger value in its increased-contrast appearance; widening
    ///   the stroke as well is what makes a card boundary unmistakable rather
    ///   than merely darker.
    /// - **Prominence** decides material versus tint, and whether a shadow is
    ///   drawn at all.
    static func resolve(
        prominence: GjuhaSurfaceProminence,
        reduceTransparency: Bool,
        increaseContrast: Bool
    ) -> GjuhaSurfaceResolution {
        let strokeWidth: CGFloat = increaseContrast ? 1.5 : 0.8

        if reduceTransparency {
            return GjuhaSurfaceResolution(
                fill: prominence == .nested ? .opaqueSurfaceSecondary : .opaqueSurface,
                // A shadow over an opaque fill still reads as depth and costs
                // nothing in legibility, so only the nested level drops it.
                hasShadow: prominence != .nested,
                strokeWidth: strokeWidth
            )
        }

        switch prominence {
        case .nested:
            return GjuhaSurfaceResolution(fill: .chipFill, hasShadow: false, strokeWidth: strokeWidth)
        case .standard, .prominent:
            return GjuhaSurfaceResolution(
                fill: .regularMaterial,
                hasShadow: true,
                strokeWidth: strokeWidth
            )
        }
    }
}

extension GjuhaSurfaceStyle {
    /// Resting fill for a text-bearing interactive control in the content layer:
    /// an answer option, a word chip, a filter pill.
    ///
    /// These were all `.ultraThinMaterial`, which was the wrong choice twice
    /// over. It is the thinnest material available, sitting directly under the
    /// text a learner has to read to answer a question, where Apple's guidance
    /// is that thicker materials give better contrast for text. And it had no
    /// Reduce Transparency answer, so a learner who had asked the system for
    /// less translucency still got the thinnest translucency the platform
    /// offers, under the most important text in the app.
    static func restingControlFill(reduceTransparency: Bool) -> AnyShapeStyle {
        reduceTransparency
            ? AnyShapeStyle(Color.gjuha.surface)
            : AnyShapeStyle(.regularMaterial)
    }

    /// Fill for a bar that floats over scrolling content, such as the action
    /// pinned below the lesson completion screen.
    ///
    /// This one *is* the functional layer, so a material belongs here. It still
    /// needs the opaque fallback.
    static func floatingBarFill(reduceTransparency: Bool) -> AnyShapeStyle {
        reduceTransparency
            ? AnyShapeStyle(Color.gjuha.background)
            : AnyShapeStyle(.bar)
    }
}

// MARK: - Modifier

private struct GjuhaSurfaceModifier: ViewModifier {
    let cornerRadius: CGFloat
    let prominence: GjuhaSurfaceProminence

    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.colorSchemeContrast) private var contrast

    private var resolution: GjuhaSurfaceResolution {
        GjuhaSurfaceStyle.resolve(
            prominence: prominence,
            reduceTransparency: reduceTransparency,
            increaseContrast: contrast == .increased
        )
    }

    func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        let resolved = resolution

        return content
            .background {
                switch resolved.fill {
                case .regularMaterial:
                    shape.fill(.regularMaterial)
                case .opaqueSurface:
                    shape.fill(Color.gjuha.surface)
                case .opaqueSurfaceSecondary:
                    shape.fill(Color.gjuha.surfaceSecondary)
                case .chipFill:
                    shape.fill(Color.gjuha.chipFill)
                }
            }
            .overlay {
                shape.stroke(Color.gjuha.hairline, lineWidth: resolved.strokeWidth)
            }
            .shadow(
                color: .black.opacity(resolved.hasShadow ? 0.12 : 0),
                radius: resolved.hasShadow ? 12 : 0,
                y: resolved.hasShadow ? 6 : 0
            )
    }
}

extension View {
    /// A content-layer card surface.
    ///
    /// This replaced `gjuhaLiquidGlassCard`, and the rename is the point. Apple's
    /// Materials guidance splits the interface into a content layer and a
    /// functional layer of controls and navigation that floats above it, and says
    /// Liquid Glass belongs only to the second: putting it in the content layer
    /// "can result in unnecessary complexity and a confusing visual hierarchy",
    /// with standard materials being the content layer's tool instead.
    ///
    /// Every one of these 30-odd surfaces is content — a card, a stat tile, a
    /// row — so none of them was ever a candidate for glass. Calling the modifier
    /// `gjuhaLiquidGlassCard` told every future reader the opposite, and the app's
    /// real functional layer (the tab bar and the navigation bar) now gets the
    /// material from the system, where it is correct and free.
    func gjuhaCardSurface(
        cornerRadius: CGFloat = GjuhaSpacing.Radius.medium,
        prominence: GjuhaSurfaceProminence = .standard
    ) -> some View {
        modifier(GjuhaSurfaceModifier(cornerRadius: cornerRadius, prominence: prominence))
    }
}

// MARK: - Ambient background

/// The app's page background: a slow accent wash behind the content layer.
///
/// Renamed from `GjuhaLiquidGlassBackground` for the same reason as the card
/// modifier. It is not glass and never was; it is a gradient with a few blurred
/// shapes, which is exactly what a content-layer background should be.
///
/// Two accessibility settings change it. Reduce Motion stops the drift, which it
/// already did. Reduce Transparency now also drops the blurred shapes and the
/// wash, leaving a flat background: the shapes are soft-edged translucent forms,
/// and keeping them while claiming to have reduced transparency would be a
/// half-answer.
struct GjuhaAmbientBackground: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @State private var drift = false

    var body: some View {
        if reduceTransparency {
            Color.gjuha.background
                .ignoresSafeArea()
        } else {
            ambient
        }
    }

    private var ambient: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color.gjuha.background,
                    Color.gjuha.accentSubtle.opacity(0.45),
                    Color.gjuha.background
                ],
                startPoint: drift ? .topLeading : .bottomTrailing,
                endPoint: drift ? .bottomTrailing : .topLeading
            )
            .animation(
                reduceMotion
                ? .linear(duration: 0.01)
                : .easeInOut(duration: 6.4).repeatForever(autoreverses: true),
                value: drift
            )

            Circle()
                .fill(Color.gjuha.glassTint.opacity(0.5))
                .frame(width: 300, height: 300)
                .blur(radius: 14)
                .offset(x: drift ? -165 : -110, y: drift ? -250 : -210)
                .animation(
                    reduceMotion
                    ? .linear(duration: 0.01)
                    : .easeInOut(duration: 5.2).repeatForever(autoreverses: true),
                    value: drift
                )

            Circle()
                .fill(Color.gjuha.accent.opacity(0.12))
                .frame(width: 260, height: 260)
                .blur(radius: 20)
                .offset(x: drift ? 175 : 130, y: drift ? 240 : 290)
                .animation(
                    reduceMotion
                    ? .linear(duration: 0.01)
                    : .easeInOut(duration: 5.8).repeatForever(autoreverses: true),
                    value: drift
                )

            RoundedRectangle(cornerRadius: 52, style: .continuous)
                .fill(Color.gjuha.glassTint.opacity(0.28))
                .frame(width: 220, height: 220)
                .blur(radius: 20)
                .rotationEffect(.degrees(drift ? 18 : -12))
                .offset(x: drift ? 150 : 205, y: drift ? -250 : -210)
                .animation(
                    reduceMotion
                    ? .linear(duration: 0.01)
                    : .easeInOut(duration: 7.2).repeatForever(autoreverses: true),
                    value: drift
                )
        }
        .ignoresSafeArea()
        .onAppear {
            if reduceMotion { return }
            drift = true
        }
    }
}
