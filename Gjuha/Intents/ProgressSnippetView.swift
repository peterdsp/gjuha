import SwiftUI

/// The card Siri shows alongside the spoken answer from `CheckProgressIntent`.
///
/// Must stay a pure function of its inputs: the system may re-render or re-run the
/// intent to redraw this card, so it reads nothing and writes nothing.
///
/// The four figures mean exactly what they mean on the Profile screen. "Mastered"
/// is the scheduler's documented mastery interval, never a count of words seen.
struct ProgressSnippetView: View {
    let streak: Int
    let totalXP: Int
    let dueCount: Int
    let wordsMastered: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Gjuha")
                .font(.system(.headline, design: .rounded, weight: .bold))
                .foregroundStyle(Color.gjuha.textPrimary)

            HStack(alignment: .top, spacing: 0) {
                SnippetStat(
                    symbol: "flame.fill",
                    tint: Color.gjuha.streak,
                    value: streak,
                    caption: "Day streak"
                )
                SnippetStat(
                    symbol: "arrow.triangle.2.circlepath",
                    tint: Color.gjuha.accent,
                    value: dueCount,
                    caption: "Due now"
                )
                SnippetStat(
                    symbol: "checkmark.seal.fill",
                    tint: Color.gjuha.success,
                    value: wordsMastered,
                    caption: "Mastered"
                )
                SnippetStat(
                    symbol: "star.fill",
                    tint: Color.gjuha.xp,
                    value: totalXP,
                    caption: "Total XP"
                )
            }
        }
        .padding(16)
    }
}

private struct SnippetStat: View {
    let symbol: String
    let tint: Color
    let value: Int
    let caption: LocalizedStringKey

    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: symbol)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(tint)
            Text(value, format: .number)
                .font(.system(.title3, design: .rounded, weight: .bold))
                .foregroundStyle(Color.gjuha.textPrimary)
            Text(caption)
                .font(.system(size: 11, weight: .medium, design: .rounded))
                .foregroundStyle(Color.gjuha.textSecondary)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity, alignment: .top)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(Text(caption))
        .accessibilityValue(Text(value, format: .number))
    }
}
