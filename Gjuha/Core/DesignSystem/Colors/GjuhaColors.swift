import SwiftUI
import WebKit
import UIKit

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

// MARK: - Liquid Glass Styling

private struct GjuhaLiquidGlassCardModifier: ViewModifier {
    let cornerRadius: CGFloat
    let tintOpacity: Double

    func body(content: Content) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(.ultraThinMaterial)
                    .overlay(
                        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                            .fill(Color.white.opacity(tintOpacity))
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(Color.white.opacity(0.24), lineWidth: 0.8)
            )
            .shadow(color: .black.opacity(0.14), radius: 14, y: 8)
    }
}

struct GjuhaLiquidGlassBackground: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var drift = false

    var body: some View {
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
                .fill(Color.white.opacity(0.15))
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
                .fill(Color.white.opacity(0.08))
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

extension View {
    func gjuhaLiquidGlassCard(cornerRadius: CGFloat = 16, tintOpacity: Double = 0.08) -> some View {
        modifier(GjuhaLiquidGlassCardModifier(cornerRadius: cornerRadius, tintOpacity: tintOpacity))
    }

    /// Constrains content to a comfortable single column reading width and centers
    /// it, so wide screens (iPad, landscape) do not stretch the single column
    /// learning UI edge to edge. On iPhone the cap is wider than the screen, so it is
    /// a no op. Apply to a screen's content, never to its full bleed background.
    func gjuhaReadableWidth(_ maxWidth: CGFloat = 620) -> some View {
        frame(maxWidth: maxWidth)
            .frame(maxWidth: .infinity)
    }
}

struct AnimatedMascotView: View {
    let size: CGFloat
    let usesGlassOrb: Bool

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var float = false

    init(size: CGFloat, usesGlassOrb: Bool = true) {
        self.size = size
        self.usesGlassOrb = usesGlassOrb
    }

    private var gifData: Data? {
        NSDataAsset(name: "MascotLoop")?.data
    }

    var body: some View {
        ZStack {
            if usesGlassOrb {
                Circle()
                    .fill(Color.gjuha.accent.opacity(0.2))
                    .frame(width: size + 8, height: size + 8)
                    .blur(radius: 12)

                Circle()
                    .fill(.ultraThinMaterial)
                    .frame(width: size, height: size)
                    .overlay(
                        Circle()
                            .stroke(Color.white.opacity(0.3), lineWidth: 0.8)
                    )
            }

            if let gifData {
                TransparentAnimatedGIFView(data: gifData)
                    .frame(width: usesGlassOrb ? size - 14 : size, height: usesGlassOrb ? size - 14 : size)
                    .clipShape(Circle())
            } else {
                Image("MascotIcon")
                    .resizable()
                    .scaledToFit()
                    .frame(width: usesGlassOrb ? size - 16 : size, height: usesGlassOrb ? size - 16 : size)
                    .scaleEffect(float ? 1.03 : 0.94)
                    .rotationEffect(.degrees(float ? -1.8 : 1.8))
                    .offset(y: float ? -2 : 3)
                    .animation(
                        reduceMotion
                        ? .linear(duration: 0.01)
                        : .easeInOut(duration: 1.1).repeatForever(autoreverses: true),
                        value: float
                    )
            }
        }
        .onAppear {
            if reduceMotion { return }
            float = true
        }
    }
}

private struct TransparentAnimatedGIFView: UIViewRepresentable {
    let data: Data

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeUIView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        configuration.allowsInlineMediaPlayback = true

        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.isOpaque = false
        webView.backgroundColor = .clear
        webView.scrollView.backgroundColor = .clear
        webView.scrollView.isScrollEnabled = false
        webView.isUserInteractionEnabled = false
        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {
        let fingerprint = data.hashValue
        guard context.coordinator.loadedFingerprint != fingerprint else { return }
        context.coordinator.loadedFingerprint = fingerprint

        let base64 = data.base64EncodedString()
        let html = """
        <html>
        <head>
        <meta name="viewport" content="initial-scale=1.0, maximum-scale=1.0">
        <style>
        html, body { margin: 0; padding: 0; background: transparent; overflow: hidden; }
        img { width: 100%; height: 100%; object-fit: contain; background: transparent; }
        </style>
        </head>
        <body>
        <img src="data:image/gif;base64,\(base64)" />
        </body>
        </html>
        """

        webView.loadHTMLString(html, baseURL: nil)
    }

    final class Coordinator {
        var loadedFingerprint: Int?
    }
}
