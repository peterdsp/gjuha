import SwiftUI

// MARK: - Primary

/// The app's primary action: a full-width accent gradient carrying `onAccent`.
///
/// This existed as a copy-pasted `Text` + `LinearGradient` + `clipShape` block in
/// four places (two lesson "Check" buttons, "Continue", "Try again"), each with
/// slightly different values. Two problems came with that:
///
/// - **No press feedback.** Every one of them was `.buttonStyle(.plain)`, so the
///   control did not react to touch at all. On a learning app where the same
///   button is pressed dozens of times a session, that reads as an unresponsive
///   tap rather than a deliberate style.
/// - **An unmeasured gradient.** The second stop was `streak.opacity(0.94)`, and
///   lightening a fill under white text lowers its contrast below the 4.5:1 the
///   palette was tuned to. The stop is now the opaque token.
struct GjuhaPrimaryButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.gjuha.labelBold)
            .foregroundStyle(Color.gjuha.onAccent)
            .frame(maxWidth: .infinity)
            .padding(.vertical, .gjuha.regular)
            .frame(minHeight: GjuhaSpacing.minimumHitTarget)
            .background(background(isPressed: configuration.isPressed))
            .clipShape(RoundedRectangle(cornerRadius: GjuhaSpacing.Radius.small, style: .continuous))
            .scaleEffect(scale(isPressed: configuration.isPressed))
            .animation(
                reduceMotion ? .linear(duration: 0.01) : .spring(response: 0.26, dampingFraction: 0.72),
                value: configuration.isPressed
            )
            .contentShape(RoundedRectangle(cornerRadius: GjuhaSpacing.Radius.small, style: .continuous))
    }

    private func scale(isPressed: Bool) -> CGFloat {
        guard isEnabled, isPressed, !reduceMotion else { return 1.0 }
        return 0.97
    }

    @ViewBuilder
    private func background(isPressed: Bool) -> some View {
        if isEnabled {
            LinearGradient(
                colors: [Color.gjuha.accent, Color.gjuha.streak],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            // Darkening on press keeps the contrast floor: a brighten would push
            // the gradient under its measured 4.85:1 with `onAccent`.
            .overlay(Color.black.opacity(isPressed ? 0.14 : 0))
        } else {
            Color.gjuha.textTertiary
        }
    }
}

// MARK: - Secondary

/// A quieter full-width action: a bordered surface carrying ordinary text. Used
/// where a screen offers a second way out that should not compete with the
/// primary ("Back to lessons", "Not now").
struct GjuhaSecondaryButtonStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.gjuha.labelBold)
            .foregroundStyle(Color.gjuha.textSecondary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, .gjuha.snug)
            .frame(minHeight: GjuhaSpacing.minimumHitTarget)
            .background(
                RoundedRectangle(cornerRadius: GjuhaSpacing.Radius.small, style: .continuous)
                    .fill(configuration.isPressed ? Color.gjuha.chipFill : Color.clear)
            )
            .overlay(
                RoundedRectangle(cornerRadius: GjuhaSpacing.Radius.small, style: .continuous)
                    .stroke(Color.gjuha.hairline, lineWidth: 0.8)
            )
            .animation(
                reduceMotion ? .linear(duration: 0.01) : .easeOut(duration: 0.16),
                value: configuration.isPressed
            )
            .contentShape(RoundedRectangle(cornerRadius: GjuhaSpacing.Radius.small, style: .continuous))
    }
}

// MARK: - Card

/// Press feedback for a whole card that acts as a button (the daily review card,
/// the culture card, a lesson node). Keeps the card's own background and only
/// adds the response to touch that `.plain` leaves out.
struct GjuhaCardButtonStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed && !reduceMotion ? 0.98 : 1.0)
            .opacity(configuration.isPressed ? 0.92 : 1.0)
            .animation(
                reduceMotion ? .linear(duration: 0.01) : .spring(response: 0.3, dampingFraction: 0.76),
                value: configuration.isPressed
            )
    }
}

extension ButtonStyle where Self == GjuhaPrimaryButtonStyle {
    static var gjuhaPrimary: GjuhaPrimaryButtonStyle { GjuhaPrimaryButtonStyle() }
}

extension ButtonStyle where Self == GjuhaSecondaryButtonStyle {
    static var gjuhaSecondary: GjuhaSecondaryButtonStyle { GjuhaSecondaryButtonStyle() }
}

extension ButtonStyle where Self == GjuhaCardButtonStyle {
    static var gjuhaCard: GjuhaCardButtonStyle { GjuhaCardButtonStyle() }
}
